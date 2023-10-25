defmodule Utils do
  @moduledoc """
  Utilitary functions
  """

  def values_from_map(map, keys \\ []) when is_map(map) and is_list(keys),
    do: Enum.map(keys, &Map.get(map, &1))

  def clean_name(name) do
    rootname = name |> Path.rootname() |> String.replace(" ", "") |> String.replace(".", "")
    rootname <> Path.extname(name)
  end

  def is_valid_url?(string) do
    URI.parse(string)
    |> Utils.values_from_map()
    |> Enum.all?()
  end

  @doc """
    Download in streams and write the stream into a temp file
  """
  def follow_redirect(url, path), do: Finch.build(:get, url) |> Utils.stream_request_into(path)

  @doc """
  Download in streams and write the stream into a temp file
  """

  def stream_request_into(req, path) do
    {:ok, file} = File.open(path, [:binary, :write])

    streaming = Utils.stream_write(req, file)

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
  We write the body of the request into a file stream by stream.
  """
  def stream_write(req, file) do
    fun = fn
      {:status, status}, _ ->
        status

      {:headers, headers}, status ->
        handle_headers(headers, status)

      {:data, data}, headers ->
        handle_data(data, headers, file)
    end

    Finch.stream(req, UpImg.Finch, nil, fun)
  end

  defp handle_headers(headers, 302) do
    Enum.find(headers, &(elem(&1, 0) == "location"))
    # |> List.first()
  end

  defp handle_headers(headers, 200) do
    headers
  end

  defp handle_headers(_headers, _status) do
    {:halt, "bad redirection"}
  end

  defp handle_data(_data, {"location", location}, file) do
    Finch.build(:get, location) |> Utils.stream_write(file)
  end

  defp handle_data(_data, {:halt, "bad redirection"}, _file) do
    {:error, "bad redirection"}
  end

  defp handle_data(data, _headers, file) do
    case IO.binwrite(file, data) do
      :ok -> :ok
      {:error, reason} -> {:error, reason}
    end
  end
end
