defmodule UpImgWeb.ApiController do
  @moduledoc """
  API endpoint to transform a picture into a WEBP and upload to S3.

  Returns a JSON response.
  """
  use UpImgWeb, :controller
  # import SweetXml

  alias UpImgWeb.ApiController, as: Api
  alias Vix.Vips.Operation

  require Logger

  @accepted_mime ["image/jpeg", "image/jpg", "image/png", "image/webp"]
  @max_w 4200
  @max_h 4000
  @max_size 5_100_000

  @doc """
  Catch all JSON response to a no-machting URL.
  """
  def no_route(conn, _params) do
    json(conn |> Plug.Conn.put_status(404), %{error: "bad request"})
  end

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

        File.stream!(path, [], 64_000)
        |> Stream.into(File.stream!(UpImg.build_path(new_name)))
        |> Stream.run()

        task_predictions =
          if maybe_predict == "on" do
            {:ok, img_for_predictions} = Vix.Vips.Image.new_from_file(new_path)

            predict(img_for_predictions)
          else
            nil
          end

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
             Vix.Vips.Image.new_from_file(file.path),
           {:ok, %{width: width, height: height}} <-
             image_get_dim(img),
           :ok <- check_dim_from_image(width, height),
           {:ok, {hor_scale, vert_scale}} <-
             parse_size(file.w, h, width, height),
           {:ok, img_resized} <-
             Api.resize(img, hor_scale, vert_scale),
           {:ok, %{width: new_w, height: new_h}} <-
             image_get_dim(img_resized),
           {:ok, resized_path} <-
             Plug.Upload.random_file("local_file"),
           :ok <-
             Operation.webpsave(img_resized, resized_path),
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
             Api.upload_to_s3(data, file.filename) do
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
          [%{label: predictions}] = Task.await(response.task_predictions).predictions
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

  def filter(file, w, h, predict) do
    with {:ok, size} <-
           check_size_file_stat(file),
         {:ok, %{mime_type: mime}} <-
           gen_magic_eval(file),
         :ok <-
           ex_image_check(file, mime),
         {:ok, img} <-
           Vix.Vips.Image.new_from_file(file),
         {:ok, %{width: width, height: height}} <-
           image_get_dim(img),
         :ok <- check_dim_from_image(width, height),
         {:ok, {hor_scale, vert_scale}} <-
           parse_size(w, h, width, height),
         {:ok, img_resized} <-
           Api.resize(img, hor_scale, vert_scale),
         {:ok, task_predictions} <-
           if(predict == "on", do: {:ok, predict(img_resized)}, else: {:ok, nil}),
         #  (predict && predict(img_resized)) || nil,
         {:ok, %{width: new_w, height: new_h}} <-
           image_get_dim(img_resized),
         {:ok, resized_path} <-
           Plug.Upload.random_file("local_file"),
         :ok <-
           Operation.webpsave(img_resized, resized_path),
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

  def predict(%Vix.Vips.Image{} = image) do
    # serving = UpImg.GsPredict.serve()

    {:ok, %Vix.Tensor{data: data, shape: shape, names: names, type: type}} =
      Vix.Vips.Image.write_to_tensor(image)

    {width, height, channels} = shape
    t_img = Nx.from_binary(data, type) |> Nx.reshape({height, width, channels}, names: names)

    # Nx.Serving.batched_run(UpImg.Serving, t_img)
    # Task.async(fn -> Nx.Serving.batched_run(UpImg.Serving, t_img) end)
    Task.async(fn -> Nx.Serving.batched_run(UpImg.Serving, t_img) end)
    # Task.async(fn -> Nx.Serving.run(serving, t_img) end)
  end

  def upload_to_s3(data, string) do
    bucket =
      if UpImg.env() == :test,
        do: System.get_env("AWS_S3_BUCKET"),
        else: UpImg.EnvReader.bucket()

    with %{size: new_size} <-
           File.stat!(data.resized_path),
         {:ok, %{body: %{location: location}}} <-
           UpImg.Upload.upload_file_to_s3(%{path: data.resized_path, filename: data.name}) do
      location = URI.parse(location)
      File.rm_rf!(data.resized_path)

      url =
        %URI{
          location
          | authority: bucket <> "." <> Map.get(location, :authority),
            host: bucket <> "." <> Map.get(location, :host),
            path: "/" <> Path.basename(Map.get(location, :path))
        }
        |> URI.to_string()

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
         if is_valid_url?(string),
           do: Map.put(res, :url_origin, string),
           else: Map.put(res, :filename, string)
       end)}
    end
  end

  def follow_redirect(url, path) do
    Finch.build(:get, url)
    |> Api.stream_request_into(path)
  end

  # def follow_redirect(url, path) do
  #   Finch.build(:get, url)
  #   |> Finch.request!(UpImg.Finch)
  #   |> case do
  #     %{status: 302, headers: headers} ->
  #       {"location", location} =
  #         Enum.find(headers, fn
  #           {"location", location} -> location
  #           {_, _} -> nil
  #         end)

  #       Finch.build(:get, location)
  #       |> stream_request_into(path)

  #     %{status: 200, body: body}  ->
  #       File.write!(path, body)
  #       {:ok, path}

  #     _ ->
  #       {:error, "too much redirects"}
  #   end
  # end

  @doc """
  GET endpoint. It receive an URL and returns a JSON response with the URL on S3 of the result.
  """
  def create(conn, %{"url" => url} = params) do
    w = Map.get(params, "w")
    h = Map.get(params, "h")
    predict = Map.get(params, "pred")

    # allow images sourced from unsplash that are redirected

    response =
      with true <-
             is_valid_url?(url),
           {:ok, stream_path} <-
             Plug.Upload.random_file("streamed"),
           {:ok, file} <-
             follow_redirect(url, stream_path),
           {:ok, data} <-
             filter(file, w, h, predict),
           {:ok, response} <-
             upload_to_s3(data, url) do
        if Map.get(response, :task_predictions) != nil do
          [%{label: predictions}] = Task.await(response.task_predictions).predictions
          {_, response} = Map.pop(response, :task_predictions)

          Map.put(response, :predictions, predictions)
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
  Returns `true` if the string is a valid URL.
  """
  def is_valid_url?(string) do
    URI.parse(string)
    |> Utils.values_from_map([:scheme, :authority, :host, :port])
    |> Enum.all?()
  end

  @doc """
  Download in streams and write the stream into a temp file
  """

def stream_request_into(req, path) do
  {:ok, file} = File.open(path, [:binary, :write])

  streaming = Api.stream_write(req, file)

  case File.close(file) do
    :ok ->
      case streaming do
        {:ok, _} ->
          {:ok, path}

        {:error, reason} ->
          {:error, reason}
      end

    {:error, reason} ->
      {:error, reason}
  end
end

@doc """
We write into a file stream by stream
"""
  def stream_write(req, file) do
    Finch.stream(req, UpImg.Finch, nil, fn
      {:status, status}, _acc -> status

      {:headers, headers}, _acc ->
        case Enum.find(headers, fn
               {"location", location} -> location
               _ -> nil
             end) do
          {"location", location} -> location
          _ -> headers
        end

      {:data, data}, acc ->
        case is_binary(acc) do
          true ->
            Finch.build(:get, acc) |> Api.stream_write(file)

          false ->
            case IO.binwrite(file, data) do
              :ok -> :ok
              {:error, reason} -> {:error, reason}
            end
        end
        # we don't return the whole binary since we put it in a temp file
    end)
  end



  @doc """
  Read with `File.stat` the size of the file.
  """
  def check_size_file_stat(path) do
    case File.stat(path) do
      {:ok, data} ->
        if data.size > @max_size, do: {:error, :too_large}, else: {:ok, data.size}

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
    %{width: width, height: height} = Vix.Vips.Image.headers(img)
    {:ok, %{width: width, height: height}}
  rescue
    e ->
      {:error, inspect(e)}
  end

  @doc """
  Filter images too large
  """
  def check_dim_from_image(w, h) do
    cond do
      w > @max_w -> {:error, :too_large}
      h > @max_h -> {:error, :too_large}
      true -> :ok
    end
  end

  @doc """
  Evaluate ExImageInfo results against GenMagic.

  !! It read the file => Sobelow warning.
  """

  # def check_headers_via_image_info(path, width, height, mime) do
  #   case ExImageInfo.info(File.read!(path)) do
  #     nil ->
  #       {:error, "not_an_accepted_type"}

  #     {^mime, ^width, ^height, _} ->
  #       {:ok, %{width: width, height: height}}

  #     res ->
  #       Logger.info(inspect(res))
  #       {:error, "does_not_match"}
  #   end
  # end

  def resize(img, horizontal_scale, vertical_scale \\ nil) do
    cond do
      horizontal_scale == nil ->
        {:ok, img}

      horizontal_scale != nil && vertical_scale == nil ->
        Operation.resize(img, horizontal_scale)

      true ->
        Operation.resize(img, horizontal_scale, vscale: vertical_scale)
    end
  end

  def parse_size(w, _h, width, _height) when is_nil(w) do
    IO.puts("is nil__")
    binding()
    {:ok, {1440 / width, nil}}
  end

  def parse_size("", _h, width, _height) do
    IO.puts("is binary nil__")
    binding()
    {:ok, {1440 / width, nil}}
  end

  def parse_size(w, h, width, height) when is_nil(h) do
    parse_size(w, "", width, height)
  end

  def parse_size(_, _, width, height) when width > 4200 or height > 4000 do
    {:error, "too_large"}
  end

  def parse_size(w, h, width, height) do
    binding()

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

# Here is the new code to be inserted
# def handle_errors(conn, params) do
#   case params do
#     %{} -> json(conn, %{error: "no parameters"})
#     _ -> conn
#   end
# end
