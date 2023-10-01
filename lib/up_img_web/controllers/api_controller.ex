defmodule UpImgWeb.ApiController do
  @moduledoc """
  API endpoint to transform a picture into a WEBP and upload to S3.

  Returns a JSON response.
  """
  use UpImgWeb, :controller
  import SweetXml

  alias UpImgWeb.ApiController, as: Api
  alias Vix.Vips.{Image, Operation}

  require Logger

  @accepted_mime ["image/jpeg", "image/jpg", "image/png", "image/webp"]
  @max_w 4200
  @max_h 4000
  @max_size 5_100_000

  @doc """
  POST endpoint to receive images files from a client
  """

  # single file
  def handle(conn, params) do
    # {:ok, body, conn} = Plug.Conn.read_part_body(conn, length: 1_000_000)
    file = Map.get(params, "file")
    w = Map.get(params, "w")
    thumb = Map.get(params, "thumb")

    case file do
      nil ->
        json(conn, %{error: "input is empty"})

      %Plug.Upload{path: path} ->
        with {:ok, data} <-
               filter(path, w, nil),
             {:ok, response} <-
               Api.upload_to_s3(data) do
          json(conn, response)
        else
          {:error, reason} ->
            json(conn, %{error: reason})
        end
    end
  end

  # multi-files
  # def handle(conn, params) do
  #   response =
  #     Api.parse_multi(params)
  #     |> dbg()

  #   json(conn, response)
  # end

  # def parse_multi(params) do
  #   values = Map.values(params)

  #   other_fields =
  #     values
  #     |> Enum.filter(&is_binary/1)
  #     |> Enum.map(&Jason.decode!/1)

  #   maybe_width = Enum.find(other_fields, &(Map.get(&1, "w") != nil))
  #   w = Map.get(maybe_width, "w")
  #   h = nil
  #   maybe_thumb = Enum.find(other_fields, &(Map.get(&1, "thumb") != nil))
  #   _thumb = Map.get(maybe_thumb, "thumb")

  #   maybe_files = Enum.filter(values, &(!is_binary(&1)))

  #   case length(maybe_files) do
  #     0 ->
  #       nil

  #     _ ->
  #       maybe_files
  #       |> Enum.reduce([], fn %Plug.Upload{filename: filename, path: path} = file, acc ->
  #         with {:ok, size} <-
  #                check_size_file_stat(path),
  #              {:ok, %{mime_type: mime}} <-
  #                gen_magic_eval(path),
  #              :ok <-
  #                ex_image_check(path, mime) do
  #           new_name = Utils.clean_name(filename)
  #           new_path = UpImg.build_path(new_name)

  #           File.stream!(path, [], 64_000)
  #           |> Stream.into(File.stream!(UpImg.build_path(new_name)))
  #           |> Stream.run()

  #           [
  #             Map.merge(file, %{
  #               filename: new_name,
  #               path: new_path,
  #               w: w,
  #               init_size: size,
  #               mime: mime
  #             })
  #             | acc
  #           ]
  #         else
  #           {:error, reason} ->
  #             Logger.info(reason)
  #             acc
  #         end
  #       end)
  #       |> Task.async_stream(fn file ->
  #         with {:ok, img} <-
  #                Image.new_from_file(file.path),
  #              {:ok, %{width: width, height: height}} <-
  #                image_get_dim(img),
  #              :ok <- check_dim_from_image(width, height),
  #              {:ok, %{width: width, height: height}} <-
  #                check_headers_via_image_info(file.path, width, height, file.mime),
  #              {:ok, {hor_scale, vert_scale}} <-
  #                parse_size(file.w, nil, width, height),
  #              {:ok, img_resized} <-
  #                Api.resize(img, hor_scale, vert_scale),
  #              {:ok, %{width: new_w, height: new_h}} <-
  #                image_get_dim(img_resized),
  #              {:ok, resized_path} <-
  #                Plug.Upload.random_file("local_file"),
  #              :ok <-
  #                Operation.webpsave(img_resized, resized_path),
  #              {:ok, name} =
  #                FileUtils.hash_file(%{path: resized_path, content_type: "image/webp"}),
  #              data <-
  #                %{
  #                  resized_path: resized_path,
  #                  init_size: file.init_size,
  #                  content_type: "image/webp",
  #                  name: name,
  #                  w_origin: width,
  #                  h_origin: height,
  #                  w: new_w,
  #                  h: new_h
  #                },
  #              {:ok, response} <-
  #                Api.upload_to_s3(data) do
  #           File.rm_rf!(file.path)
  #           %{res: response}
  #         else
  #           {:error, reason} ->
  #             Logger.info(inspect(reason))
  #             %{error: reason}
  #         end
  #       end)
  #       |> Stream.run()
  #   end
  # end

  def filter(file, w, h) do
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
         {:ok, %{width: width, height: height}} <-
           check_headers_via_image_info(file, width, height, mime),
         {:ok, {hor_scale, vert_scale}} <-
           parse_size(w, h, width, height),
         {:ok, img_resized} <-
           Api.resize(img, hor_scale, vert_scale),
         {:ok, %{width: new_w, height: new_h}} <-
           image_get_dim(img_resized),
         {:ok, resized_path} <-
           Plug.Upload.random_file("local_file"),
         :ok <-
           Operation.webpsave(img_resized, resized_path),
         {:file_exists, true} <-
           {:file_exists, File.exists?(resized_path)},
         {:ok, name} =
           FileUtils.hash_file(%{path: resized_path, content_type: "image/webp"}) do
      {:ok,
       %{
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

  def upload_to_s3(data) do
    bucket =
      if UpImg.env() == :test,
        do: System.get_env("AWS_S3_BUCKET"),
        else: UpImg.EnvReader.bucket()

    %{size: new_size} = File.stat!(data.resized_path)

    with {:ok, %{body: body}} <-
           UpImg.Upload.upload_file_to_s3(%{path: data.resized_path, filename: data.name}) do
      attached = body |> xpath(~x"//text()") |> List.to_string() |> URI.parse()
      File.rm_rf!(data.resized_path)

      url =
        %URI{
          attached
          | authority: bucket <> "." <> Map.get(attached, :authority),
            host: bucket <> "." <> Map.get(attached, :host),
            path: "/" <> Path.basename(Map.get(attached, :path))
        }
        |> URI.to_string()

      {:ok,
       %{
         w_origin: data.w_origin,
         h_origin: data.h_origin,
         init_size: data.init_size,
         w: data.w,
         h: data.h
       }
       |> Map.put(:url, url)
       |> Map.put(:new_size, new_size)}
    end
  end

  def create(conn, %{"url" => url} = params) do
    w = Map.get(params, "w")
    h = Map.get(params, "h")

    response =
      with true <-
             check_url(url),
           req <-
             Finch.build(:get, url),
           {:ok, stream_path} <-
             Plug.Upload.random_file("streamed"),
           {:ok, file} <-
             stream_request_into(req, stream_path),
           {:ok, data} <-
             filter(file, w, h),
           {:ok, response} <-
             upload_to_s3(data) do
        response
      else
        false ->
          {:error, :bad_url}

        {:file_exists, false} ->
          {:error, "Please retry"}

        {:no_tmp, msg} ->
          Logger.warning(inspect(msg))
          {:error, inspect(msg)}

        {:too_many_attemps, msg} ->
          Logger.warning(inspect(msg))
          {:error, inspect(msg)}

        {:error, msg} ->
          Logger.warning(inspect(msg))
          {:error, inspect(msg)}
      end

    case response do
      {:error, :bad_url} ->
        json(conn, %{error: :bad_url})

      {:error, reason} ->
        json(conn, %{error: reason})

      response ->
        json(conn, response)
    end
  end

  def create(conn, params) do
    if Map.get(params, "url") == nil, do: json(conn, %{error: "Please provide an URL"})
  end

  def check_url(url) do
    URI.parse(url)
    |> Utils.values_from_map([:scheme, :authority, :host, :port])
    |> Enum.all?()
  end

  @doc """
  Download in streams and write the stream into a temp file
  """
  def stream_request_into(req, path) do
    {:ok, file} = File.open(path, [:binary, :write])

    streaming =
      Finch.stream(req, UpImg.Finch, nil, fn
        {:status, status}, _acc ->
          status

        {:headers, headers}, _acc ->
          headers

        {:data, data}, _acc ->
          case IO.binwrite(file, data) do
            :ok -> :ok
            {:error, reason} -> {:error, reason}
          end

          # we don't return the whole binary since we put it in a temp file
      end)

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
  Read with `File.stat` the size of the file.
  """
  def check_size_file_stat(path) do
    Logger.info("downloaded..........")

    case File.stat(path) do
      {:ok, data} ->
        if data.size > @max_size, do: {:error, :too_large}, else: {:ok, data.size}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Check file type via magic number and C lib "libmagic"
  """
  def gen_magic_eval(path) do
    case GenMagic.Server.perform(:gen_magic, path) do
      {:error, reason} ->
        {:error, reason}

      {:ok,
       %GenMagic.Result{
         mime_type: mime,
         encoding: "binary",
         content: _content
       }} ->
        if Enum.member?(@accepted_mime, mime),
          do: {:ok, %{mime_type: mime}},
          else: {:error, :bad_mime}

      {:ok, %GenMagic.Result{} = res} ->
        Logger.warning(%{gen_magic_response: res})
        {:error, :not_acceptable}
    end
  end

  def ex_image_check(file, mime) when is_binary(file) do
    case ExImageInfo.info(File.read!(file)) do
      nil ->
        {:error, "Unable to read the file"}

      {^mime, _w, _h, _} ->
        :ok

      {type, _, _, _} ->
        Logger.info(%{content_type: type})
        {:error, "suspicious file"}
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
  def check_headers_via_image_info(path, width, height, mime) do
    case ExImageInfo.info(File.read!(path)) do
      nil ->
        {:error, :not_an_accepted_type}

      {^mime, ^width, ^height, _} ->
        {:ok, %{width: width, height: height}}

      res ->
        Logger.info(inspect(res))
        {:error, :does_not_match}
    end
  end

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
    {:error, :too_large}
  end

  def parse_size(w, h, width, height) do
    binding()

    case {Integer.parse(w), Integer.parse(h)} do
      {:error, :error} ->
        {:error, :wrong_format}

      {:error, {_h_int, _}} ->
        {:error, :wrong_format}

      {{w_int, _}, :error} ->
        {:ok, {w_int / width, nil}}

      {{w_int, _}, {h_int, _}} ->
        {:ok, {w_int / width, h_int / height}}
    end
  end
end
