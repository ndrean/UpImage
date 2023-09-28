defmodule UpImgWeb.ApiController do
  @moduledoc """
  API endpoint to transform a picture into a WEBP and upload to S3.

  Returns a JSON response.
  """
  use UpImgWeb, :controller
  import SweetXml

  alias UpImgWeb.ApiController
  alias UpImgWeb.NoClientLive
  alias Vix.Vips.{Image, Operation}
  require Logger

  @accepted_files ["jpeg", "jpg", "png", "webp"]
  @max_w 4200
  @max_h 4000
  @max_size 5_100_000

  def values_from_map(map, keys \\ []) when is_map(map) and is_list(keys),
    do: Enum.map(keys, &Map.get(map, &1))

  def check_url(url) do
    URI.parse(url)
    |> values_from_map([:scheme, :authority, :host, :port])
    |> Enum.all?()
  end

  @spec parse_size(any, any, any, any) ::
          {:error, :too_large | :wrong_format} | {:ok, {float, nil | float}}
  def parse_size(w, _h, width, _height) when is_nil(w) do
    {:ok, {1440 / width, nil}}
  end

  def parse_size(w, h, width, height) when is_nil(h) do
    parse_size(w, "", width, height)
  end

  def parse_size(_, _, width, height) when width > 4200 or height > 4000 do
    {:error, :too_large}
  end

  def parse_size(w, h, width, height) do
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

  @spec get_sizes_from_image(any) ::
          {:error, :image_not_readable} | {:ok, {pos_integer, pos_integer}}
  def get_sizes_from_image(img) do
    width = Image.width(img)
    height = Image.height(img)
    {:ok, {width, height}}
  rescue
    _ ->
      {:error, :image_not_readable}
  end

  @spec resize(any, any, any) :: {:error, any} | {:ok, any}
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

  # to continue the POST endpoint, and accept a multipart.
  #  move NoClientLive.build_path  into UpImg.
  def create(conn, %{"path" => path, "name" => name} = params) do
    w = Map.get(params, "w")
    h = Map.get(params, "h")

    new_path = NoClientLive.build_path(name)

    response =
      with {:ok, img} <- Image.new_from_file(path),
           {:ok, {width, height}} <- ApiController.get_sizes_from_image(img),
           {:ok, {w, h}} <- parse_size(w, h, width, height),
           {:ok, img_resized} <- ApiController.resize(img, h, w),
           :ok <-
             Operation.webpsave(img_resized, new_path) do
        {:ok, %{url: url}} =
          UpImg.Upload.upload(%{content_type: "image/webp", name: name, path: new_path})

        File.rm_rf!(new_path)
        {:ok, url}
      else
        {:error, :image_not_readable} -> {:error, :image_not_readable}
        {:error, reason} -> {:error, reason}
      end

    case response do
      {:ok, url} ->
        json(conn, %{url: url})

      {:error, reason} ->
        json(conn, %{error: inspect(reason)})
    end
  end

  def create(conn, %{"url" => url, "name" => name} = params) do
    w = Map.get(params, "w")
    h = Map.get(params, "h")

    case check_url(url) do
      false ->
        json(conn, %{error: :bad_url})

      true ->
        response =
          with req <- Finch.build(:get, url),
               {:ok, stream_path} <-
                 Plug.Upload.random_file("streamed"),
               {:ok, file} <-
                 stream_request_into(req, stream_path),
               :ok <- check_size(file),
               {:ok, img} <-
                 Image.new_from_file(file),
               %{width: width, height: height} <-
                 Image.headers(img),
               {:ok, {hor_scale, vert_scale}} <-
                 parse_size(w, h, width, height),
               {:ok, img_resized} <-
                 ApiController.resize(img, hor_scale, vert_scale),
               {:ok, path} <-
                 Plug.Upload.random_file("local_file"),
               :ok <-
                 Operation.webpsave(img_resized, path) do
            stream =
              ExAws.S3.Upload.stream_file(path)

            req =
              ExAws.S3.upload(stream, UpImg.EnvReader.bucket(), name <> ".webp",
                acl: :public_read,
                content_type: "image/webp"
              )

            {:ok, %{body: body}} = ExAws.request(req)

            File.rm_rf!(file)
            %{url: body |> xpath(~x"//text()") |> List.to_string()}
          else
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
          {:error, reason} -> json(conn, %{error: reason})
          response -> json(conn, response)
        end
    end
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
          :ok = IO.binwrite(file, data)
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
  def check_size(path) do
    case File.stat(path) do
      {:ok, data} ->
        if data.size > @max_size, do: {:error, :too_large}, else: :ok

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Evaluate with ExImageInfo the type of the image
  """
  def check_file_headers(path) do
    case ExImageInfo.info(File.read!(path)) do
      nil ->
        {:error, :not_an_accepted_type}

      {type, w, h, _} ->
        check_headers(type, w, h)
    end
  end

  @doc """
  Screen the results of `check_file_headers/1`
  """
  def check_headers(type, w, h) do
    case String.split(type, "/") do
      ["image", ext] ->
        cond do
          Enum.member?(@accepted_files, ext) == false -> {:error, :not_an_accepted_type}
          :error == check_dim(w, h) -> {:error, :not_an_accepted_type}
          true -> :ok
        end

      _ ->
        {:error, :not_an_accepted_type}
    end
  end

  def check_dim(w, h) do
    cond do
      w > @max_w -> :error
      h > @max_h -> :error
      true -> :ok
    end
  end
end
