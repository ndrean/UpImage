defmodule UpImgWeb.ApiController do
  use UpImgWeb, :controller
  import SweetXml

  alias UpImgWeb.NoClientLive
  alias Vix.Vips.{Image, Operation}
  require Logger

  def parse_size(w, h, _width, _height) when is_nil(h) or is_nil(w) do
    IO.puts("nil")
    {:ok, {1, 1}}
  end

  # def parse_size(w, h, width, height) when is_integer(w) and is_integer(h) do
  #   {:ok, {w, h}}
  # end

  def parse_size(w, h, width, height) when is_integer(w) == false and is_integer(h) == false do
    IO.puts("resize")

    case {Integer.parse(w), Integer.parse(h)} do
      {:error, _} ->
        {:error, :wrong_format}

      {_, :error} ->
        {:error, :wrong_format}

      {{w_int, _}, {h_int, _}} ->
        {:ok, {w_int / width, h_int / height}}
    end
    |> dbg()
  end

  def check_url(url) do
    %URI{
      scheme: scheme,
      authority: auth,
      host: host,
      port: port,
      path: path,
      query: _query
    } = URI.parse(url)

    case Enum.any?([scheme, auth, host, port, path]) do
      true ->
        :ok

      false ->
        :error
    end
  end

  def get_sizes_from_image(img) do
    width = Image.width(img)
    height = Image.height(img)
    {width, height}

    if is_integer(width) and width != 0 and is_integer(height) and height != 0 do
      {:ok, {width, height}}
    else
      {:error, :image_not_reaable}
    end
  end

  def create(conn, %{"path" => path, "name" => name} = params) do
    w = Map.get(params, "w")
    h = Map.get(params, "h")

    new_path = NoClientLive.build_path(name)

    response =
      with {:ok, img} <- Image.new_from_file(path),
           {:ok, {width, height}} <- get_sizes_from_image(img),
           {:ok, {w, h}} <- parse_size(w, h, width, height),
           {:ok, img_resized} <- Operation.resize(img, h, vscale: w),
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
      :error ->
        json(conn, %{error: :bad_url})

      :ok ->
        response =
          case Finch.build(:get, url) |> Finch.request(UpImg.Finch) do
            {:error, reason} ->
              {:error, reason}

            {:ok, %{status: 200, body: body}} ->
              with {:ok, img} <- Image.new_from_buffer(body),
                   %{width: width, height: height} <- Image.headers(img),
                   {:ok, {ww, hh}} <- parse_size(w, h, width, height),
                   {:ok, img_resized} <-
                     Operation.resize(img, hh, vscale: ww),
                   {:ok, path} <- Plug.Upload.random_file("local_file"),
                   :ok <- Operation.webpsave(img_resized, path),
                   stream <- ExAws.S3.Upload.stream_file(path),
                   req <-
                     ExAws.S3.upload(stream, UpImg.EnvReader.bucket(), name <> ".webp",
                       acl: :public_read,
                       content_type: "image/webp"
                     ),
                   {:ok, %{body: body}} <- ExAws.request(req) do
                File.rm_rf!(path)

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
          end

        case response do
          {:error, reason} -> json(conn, %{error: reason})
          response -> json(conn, response)
        end
    end
  end
end
