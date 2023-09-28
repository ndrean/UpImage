defmodule UpImgWeb.ApiController do
  use UpImgWeb, :controller
  import SweetXml

  alias UpImgWeb.NoClientLive
  alias Vix.Vips.{Image, Operation}
  require Logger

  def values_from_map(map, keys \\ []) when is_map(map) and is_list(keys),
    do: Enum.map(keys, &Map.get(map, &1))

  def check_url(url),
    do:
      URI.parse(url)
      |> values_from_map([:scheme, :authority, :host, :port])
      |> Enum.all?()

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

  def get_sizes_from_image(img) do
    width = Image.width(img)
    height = Image.height(img)
    {width, height}

    if is_integer(width) and width != 0 and is_integer(height) and height != 0 do
      {:ok, {width, height}}
    else
      {:error, :image_not_readable}
    end
  rescue
    _ ->
      {:error, :image_not_readable}
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

  # to continue the POST endpoint, and accept a multipart.
  def create(conn, %{"path" => path, "name" => name} = params) do
    w = Map.get(params, "w")
    h = Map.get(params, "h")

    # TODO move this into UpImg.
    new_path = NoClientLive.build_path(name)

    response =
      with {:ok, img} <- Image.new_from_file(path),
           {:ok, {width, height}} <- get_sizes_from_image(img),
           {:ok, {w, h}} <- parse_size(w, h, width, height),
           {:ok, img_resized} <- resize(img, h, w),
           :ok <-
             Operation.webpsave(img_resized, new_path) do
        {:ok, %{url: url}} =
          UpImg.Upload.upload(%{content_type: "image/webp", name: name, path: new_path})

        File.rm_rf!(new_path)
        {:ok, url}
      else
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
          with {:ok, %{status: 200, body: body}} <-
                 Finch.request(Finch.build(:get, url), UpImg.Finch),
               {:ok, p} <-
                 check_body(body),
               {:ok, img} <-
                 Image.new_from_file(p),
               %{width: width, height: height} <-
                 Image.headers(img),
               {:ok, {hor_scale, vert_scale}} <-
                 parse_size(w, h, width, height),
               {:ok, img_resized} <-
                 resize(img, hor_scale, vert_scale),
               {:ok, path} <-
                 Plug.Upload.random_file("local_file"),
               :ok <-
                 Operation.webpsave(img_resized, path),
               stream <-
                 ExAws.S3.Upload.stream_file(path),
               req <-
                 ExAws.S3.upload(stream, UpImg.EnvReader.bucket(), name <> ".webp",
                   acl: :public_read,
                   content_type: "image/webp"
                 ),
               {:ok, %{body: body}} <-
                 ExAws.request(req) do
            File.rm_rf!(p)
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

            {:error, reason} ->
              %{error: reason}
          end

        case response do
          {:error, reason} -> json(conn, %{error: reason})
          response -> json(conn, response)
        end
    end
  end

  def check_body(body) do
    {:ok, p} = Plug.Upload.random_file("local")

    case save_to_file(p, body) do
      :ok ->
        {:ok, p}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def save_to_file(path, binary) do
    saving =
      case File.open(path, [:binary, :write]) do
        {:ok, file} ->
          IO.binwrite(file, binary)
          File.close(file)

        {:error, reason} ->
          {:error, reason}
      end

    case saving do
      :ok ->
        case GenMagic.Helpers.perform_once(path) do
          {:ok, %{mime_type: type}} ->
            case String.contains?(type, "image") do
              true -> :ok
              false -> {:error, :not_an_accepted_type}
            end
        end

      {:error, reason} ->
        {:error, reason}
    end
  end
end
