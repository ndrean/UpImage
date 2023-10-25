defmodule UpImgWeb.ApiController do
  @moduledoc """
  API endpoint to transform a picture into a WEBP and upload to S3.

  Returns a JSON response.
  """
  use UpImgWeb, :controller
  # import SweetXml

  alias ExAws.S3
  alias UpImg.EnvReader
  alias UpImgWeb.ApiController, as: Api
  alias Vix.Vips.{Image, Operation}

  require Logger

  @accepted_mime ["image/jpeg", "image/jpg", "image/png", "image/webp"]
  @max_w 4200
  @max_h 4000
  @max_size 5_100_000

  def no_route(conn, _) do
    json(conn, %{error: "nothing to do"})
  end

  def r2_handle(conn, params) do
    maybe_uploads =
      Map.values(params)
      |> Enum.filter(fn
        %Plug.Upload{} -> true
        _ -> false
      end)

    maybe_predict =
      Map.get(params, "predict")
      |> dbg()

    bucket = EnvReader.bucket()
    endpoint = EnvReader.endpoint()

    case maybe_uploads do
      [] ->
        json(conn, %{error: "no file"})

      files ->
        locations =
          try do
            Task.Supervisor.async_stream(UpImg.TaskSup, files, fn
              %Plug.Upload{path: path, filename: filename} = _upload ->
                {:ok, %{mime_type: mime}} = gen_magic_eval(path)

                {:ok, %{body: %{location: location, key: key}, status_code: 200}} =
                  path
                  |> S3.Upload.stream_file()
                  |> S3.upload(bucket, URI.encode(filename),
                    acl: :public_read,
                    content_type: mime,
                    content_disposition: "inline"
                  )
                  |> ExAws.request()
            end)
            |> Enum.map(fn {:ok, response} ->
              {:ok, %{body: body, status_code: 200}} = response
              endpoint <> body.location
            end)
          rescue
            error -> json(conn, inspect(error))
          end

        json(conn, %{urls: locations})
    end
  end

  # JSON can't manage binray data so it needs to be converted into seomthing
  # that can be enconded in JSON, such as a base64 string.

  @doc """
  POST endpoint to handle files from FormData

  It uses the custom multipart parser.
  """

  # multi-files
  def handle(conn, params) when map_size(params) > 0 do
    response =
      params
      |> Api.parse_params()
      |> Api.parse_multi()
      |> Enum.reduce([], fn
        {:ok, data}, acc ->
          data.url

          [data | acc]

        {:error, _}, acc ->
          acc
      end)

    json(conn, %{data: response})
  end

  def handle(conn, %{}) do
    json(conn, %{error: "no file input"})
  end

  def parse_params(params) do
    maybe_width = Map.get(params, "w", 1440)
    h = nil

    maybe_thumb = Map.get(params, "thumb", "off")
    maybe_predict = Map.get(params, "predict", "off")

    maybe_files =
      params
      |> Map.values()
      |> Enum.filter(fn
        %Plug.Upload{} = val ->
          val

        _ ->
          nil
      end)

    {maybe_width, h, maybe_files, maybe_thumb, maybe_predict}
  end

  def parse_multi({_maybe_width, _h, [], _maybe_thumb, _}), do: nil

  def parse_multi({maybe_width, h, maybe_files, _maybe_thumb, maybe_predict}) do
    maybe_files
    |> Enum.reduce([], fn %Plug.Upload{filename: filename, path: path} = file, acc ->
      with {:ok, size} <-
             check_size_file_stat(path),
           {:ok, %{mime_type: mime}} <-
             gen_magic_eval(path),
           :ok <-
             ex_image_check(path, mime) do
        # copy temp file in "priv/static/image_uploads
        new_name = Utils.clean_name(filename)
        new_path = UpImg.build_path(new_name)

        # copy file located at "path" into another one in "priv/static/image_uploads"
        File.stream!(path, [], 64_000)
        |> Stream.into(File.stream!(UpImg.build_path(new_name)))
        |> Stream.run()

        task_predictions = handle_predictions(maybe_predict, new_path)

        # add file to the list
        [
          Map.merge(file, %{
            filename: new_name,
            path: new_path,
            w: maybe_width,
            init_size: size,
            mime: mime,
            task_predictions: task_predictions,
            pid: self()
          })
          | acc
        ]
      else
        {:error, reason} ->
          Logger.info(reason)
          acc
      end
    end)
    # each file is streamed to S3 after some checks and resizing upon request.
    |> Task.async_stream(fn file ->
      with {:ok, img} <-
             Image.new_from_file(file.path),
           {:ok, %{width: width, height: height}} <-
             image_get_dim(img),
           :ok <- check_dim_from_image(width, height),
           {:ok, {hor_scale, vert_scale}} <-
             parse_size(file.w, h, width, height),
           {:ok, image_resized} <-
             Api.image_resize(img, hor_scale, vert_scale),
           {:ok, %{width: new_w, height: new_h}} <-
             image_get_dim(image_resized),
           {:ok, resized_path} <-
             Plug.Upload.random_file("local_file"),
           :ok <-
             Operation.webpsave(image_resized, resized_path),
           {:ok, name} =
             FileUtils.hash_file(%{path: resized_path, content_type: "image/webp"}),
           data <-
             %{
               task_predictions: file.task_predictions,
               resized_path: resized_path,
               init_size: file.init_size,
               content_type: "image/webp",
               name: name,
               w_origin: width,
               h_origin: height,
               w: new_w,
               h: new_h
             },
           {:ok, response} <-
             Api.upload_to_bucket(data, file.filename) do
        File.rm_rf!(file.path)

        response
        |> Map.put(:task_predictions, data.task_predictions)
      else
        {:no_tmp, reason} ->
          {:error, reason}

        {:too_many_attempts, reason} ->
          {:error, reason}

        {:error, reason} ->
          Logger.info(inspect(reason))
          {:error, reason}
      end
    end)
    |> Enum.map(fn
      {:ok, response} ->
        if Map.get(response, :task_predictions) != nil do
          [%{label: predictions}] =
            Task.await(response.task_predictions, 10_000).predictions

          {_, response} = Map.pop(response, :task_predictions)

          {
            :ok,
            response
            |> Map.put(:predictions, predictions)
          }
        else
          {:ok, response}
        end

      {:error, reason} ->
        {:error, reason}
    end)
  end

  defp handle_predictions("on", new_path) do
    Task.Supervisor.async(
      UpImg.TaskSup,
      fn ->
        {:ok, img_for_predictions} = Image.new_from_file(new_path)
        predict(img_for_predictions)
      end,
      on_timeout: :exit
    )
  end

  defp handle_predictions(_, _) do
    nil
  end

  def filter(file, w, h, predict) do
    with {:ok, size} <-
           check_size_file_stat(file),
         {:ok, %{mime_type: mime}} <-
           gen_magic_eval(file),
         :ok <-
           ex_image_check(file, mime),
         {:ok, img} <-
           Image.new_from_file(file),
         {:ok, %{width: width, height: height}} <-
           image_get_dim(img),
         :ok <- check_dim_from_image(width, height),
         {:ok, {hor_scale, vert_scale}} <-
           Api.parse_size(w, h, width, height),
         {:ok, image_resized} <-
           Api.image_resize(img, hor_scale, vert_scale),
         {:ok, task_predictions} <-
           task_perhaps_predict(img, width, height, predict),
         {:ok, %{width: new_w, height: new_h}} <-
           image_get_dim(image_resized),
         {:ok, resized_path} <-
           Plug.Upload.random_file("local_file"),
         :ok <-
           Operation.webpsave(image_resized, resized_path),
         {:file_exists, true} <-
           {:file_exists, File.exists?(resized_path)},
         {:ok, name} <-
           FileUtils.hash_file(%{path: resized_path, content_type: "image/webp"}) do
      {:ok,
       %{
         task_predictions: task_predictions,
         resized_path: resized_path,
         init_size: size,
         content_type: mime,
         name: name,
         w_origin: width,
         h_origin: height,
         w: new_w,
         h: new_h
       }}
    end
  end

  def upload_to_bucket(data, string) do
    # bucket =
    #   if UpImg.env() == :test,
    #     do: System.get_env("AWS_S3_BUCKET"),
    #     else: EnvReader.bucket()

    with %{size: new_size} <-
           File.stat!(data.resized_path),
         {:ok, %{body: %{location: location}}} <-
           UpImg.Upload.upload_file_to_bucket(%{path: data.resized_path, filename: data.name}) do
      path = URI.parse(location).path
      File.rm_rf!(data.resized_path)

      url = "https://" <> EnvReader.endpoint() <> path

      {:ok,
       %{
         w_origin: data.w_origin,
         h_origin: data.h_origin,
         init_size: data.init_size,
         w: data.w,
         h: data.h,
         task_predictions: data.task_predictions
       }
       |> Map.put(:url, url)
       |> Map.put(:new_size, new_size)
       |> then(fn res ->
         if Utils.is_valid_url?(string),
           do: Map.put(res, :url_origin, string),
           else: Map.put(res, :filename, string)
       end)}
    end
  end

  @doc """
  GET endpoint. It receive an URL and returns a JSON response with the URL on S3 of the result.
  """
  def create(conn, %{"url" => url} = params) do
    w = Map.get(params, "w")
    h = Map.get(params, "h")
    predict_on = Map.get(params, "pred")

    # allow images sourced from unsplash that are redirected

    response =
      with true <-
             Utils.is_valid_url?(url),
           {:ok, stream_path} <-
             Plug.Upload.random_file("streamed"),
           {:ok, file} <-
             Utils.follow_redirect(url, stream_path),
           {:ok, data} <-
             filter(file, w, h, predict_on),
           {:ok, response} <-
             upload_to_bucket(data, url) do
        if Map.get(response, :task_predictions) != nil do
          try do
            [%{text: predictions}] =
              Task.await(response.task_predictions, 10_000).results

            {_, response} = Map.pop(response, :task_predictions)

            Map.put(response, :predictions, predictions)
          rescue
            :exit ->
              {:error, "timeout"}
          end
        else
          response
        end
      else
        false ->
          {:error, :bad_url}

        {:file_exists, false} ->
          {:error, "Please retry"}

        {:no_tmp, msg} ->
          Logger.warning(inspect(msg))
          {:error, msg}

        {:too_many_attemps, msg} ->
          Logger.warning(inspect(msg))
          {:error, msg}

        {:error, msg} ->
          Logger.warning(inspect(msg))
          {:error, msg}
      end

    case response do
      {:error, :bad_url} ->
        json(conn, %{error: "bad url"})

      {:error, reason} ->
        json(conn, %{error: inspect(reason)})

      response ->
        json(conn, response)
    end
  end

  def create(conn, params) do
    if Map.get(params, "url") == nil do
      json(conn, %{error: "Please provide an URL"})
    end
  end

  @doc """
  Read with `File.stat` the size of the file.
  """
  def check_size_file_stat(path) do
    case File.stat(path) do
      {:ok, data} ->
        if data.size > @max_size,
          do: {:error, :too_large},
          else: {:ok, data.size}

      {:error, reason} ->
        {:error, inspect(reason)}
    end
  end

  @doc """
  Check file type via magic number. It uses a GenServer running the `C` lib "libmagic".
  """
  def gen_magic_eval(path) do
    case GenMagic.Server.perform(:gen_magic, path) do
      {:error, reason} ->
        {:error, inspect(reason)}

      {:ok,
       %GenMagic.Result{
         mime_type: mime,
         encoding: "binary",
         content: _content
       }} ->
        if Enum.member?(@accepted_mime, mime),
          do: {:ok, %{mime_type: mime}},
          else: {:error, "bad mime"}

      {:ok, %GenMagic.Result{} = res} ->
        Logger.warning(%{gen_magic_response: res})
        {:error, "not acceptable"}
    end
  end

  @doc """
  Counter-check with ExImage the findings of `gem_magic`. It reads the file.
  It determines if the file is an acceptable image and matches `gen_magic`.

  !! It reads the file => Sobelow warning.
  """
  def ex_image_check(file, mime) when is_binary(file) do
    case ExImageInfo.info(File.read!(file)) do
      nil ->
        {:error, "Error reading the file"}

      {^mime, _w, _h, _} ->
        :ok

      {type, _, _, _} ->
        Logger.info(%{content_type: type})
        {:error, "Does not match"}
    end
  end

  @doc """
  Read Vix image dimensions
  """
  def image_get_dim(img) do
    %{width: width, height: height} = Image.headers(img)
    {:ok, %{width: width, height: height}}
  rescue
    e ->
      {:error, inspect(e)}
  end

  @doc """
  Filter images too large
  """
  def check_dim_from_image(w, _) when w > @max_w, do: {:error, :too_large}
  def check_dim_from_image(_, h) when h > @max_h, do: {:error, :too_large}
  def check_dim_from_image(_, _), do: :ok

  def image_resize(img, horizontal_scale, vertical_scale \\ nil) do
    cond do
      horizontal_scale == nil ->
        {:ok, img}

      horizontal_scale != nil && vertical_scale == nil ->
        Operation.resize(img, horizontal_scale)

      true ->
        Operation.resize(img, horizontal_scale, vscale: vertical_scale)
    end
  end

  @doc """
  Defines teh horizontal & vertical scale for ML image size

  ## Example

      iex> ApiController.ml_resize(500,300) == {1,nil}
      true
      iex> ApiController.ml_resize(550, 300) == {512/550, nil}
      true
      iex> ApiController.ml_resize(300, 500) == {1,nil}
      true
      iex> ApiController.ml_resize(600, 700) == {512/700, nil}
      true
      iex> ApiController.ml_resize(700, 600) == {512/700, nil}
      true
  """
  def ml_rescale(w, h) do
    cond do
      w > h and w > 512 ->
        {512 / w, nil}

      h >= w and h > 512 ->
        {512 / h, nil}

      true ->
        {1, nil}
    end
  end

  def predict(%Vix.Vips.Image{} = image) do
    case Process.whereis(UpImg.Serving) do
      nil ->
        # maybe the model is not yet fully loaded
        Process.sleep(1_000)
        predict(image)

      _pid ->
        {:ok, %Vix.Tensor{data: data, shape: shape, names: names, type: type}} =
          Image.write_to_tensor(image)

        t_img = Nx.from_binary(data, type) |> Nx.reshape(shape, names: names)

        Nx.Serving.batched_run(UpImg.Serving, t_img)
    end
  end

  def task_perhaps_predict(img, w, h, "on") do
    {new_h_scale, new_v_scale} =
      ml_rescale(w, h)

    {:ok,
     Task.Supervisor.async_nolink(UpImg.TaskSup, fn ->
       {:ok, image_resized} = Api.image_resize(img, new_h_scale, new_v_scale)
       #  {Image.width(image_resized), Image.height(image_resized)}

       Api.predict(image_resized)
     end)}
  end

  def task_perhaps_predict(_img, _w, _h, _), do: {:ok, nil}

  # ML classification works best if image is smaller than 512x512

  def parse_size(nil, _, width, _) when width > 1400, do: {:ok, {1440 / width, nil}}

  def parse_size(nil, _, width, _) when width <= 1400, do: {:ok, {1, nil}}

  def parse_size("", _h, width, _height), do: {:ok, {1440 / width, nil}}

  def parse_size(w, nil, width, height), do: parse_size(w, "", width, height)

  def parse_size(_, _, width, height) when width > 4200 or height > 4000 do
    {:error, "too_large"}
  end

  def parse_size(w, h, width, height) do
    case {Integer.parse(w), Integer.parse(h)} do
      {:error, _} ->
        {:error, "wrong_format"}

      {{w_int, _}, :error} ->
        {:ok, {w_int / width, nil}}

      {{w_int, _}, {h_int, _}} ->
        {:ok, {w_int / width, h_int / height}}
    end
  end
end
