defmodule FileUtils do
  @moduledoc """
  This module retrieves information about files using the unix command "file".
  It just gives you the files MIME-type in a string representation.
  """
  require Logger

  def hash_file(image) do
    ext = image.content_type |> MIME.extensions() |> List.first()

    try do
      sha = FileUtils.sha256(image.path)

      case {sha, ext} do
        {_, nil} ->
          Logger.error("File extension is invalid: #{inspect(image)}")
          {:error, :invalid_extension}

        {sha, ext} ->
          {:ok, sha <> "." <> ext}
      end
    rescue
      e in File.Error ->
        Logger.error(inspect(e.reason))
        {:error, :file_error}
    end
  end

  @doc """
  Hash a file
  """
  def sha256(path) do
    cond do
      File.exists?(path) ->
        File.stream!(path, [], 2048)
        |> Enum.reduce(:crypto.hash_init(:sha256), fn curr_chunk, prev ->
          :crypto.hash_update(prev, curr_chunk)
        end)
        |> :crypto.hash_final()
        |> terminate()

      is_binary(path) ->
        :crypto.hash(:sha256, path)
        |> terminate()

      true ->
        nil
    end
  end

  @doc """
  HMAC hash used to produce a short name
  """
  def terminate(string) do
    :crypto.macN(:hmac, :sha256, "tiny URL", string, 16)
    |> Base.encode16()
    |> String.slice(0, 8)
  end

  def info(names) when is_list(names) do
    Enum.map(names, &info(&1))
  end

  def info(name) when is_binary(name) do
    case File.exists?(name) do
      false ->
        {:error, "File does not exist"}

      true ->
        {result, 0} = System.cmd("file", ["--mime-type" | [name]])

        [n, mime] =
          result
          |> String.split("\n")
          |> Stream.filter(&(&1 !== ""))
          |> Stream.map(&String.split(&1, ": "))
          |> Enum.into([])
          |> List.flatten()

        {:ok,
         %{
           short_name: Path.basename(n),
           type: mime,
           path: name,
           displayed_ext: Path.extname(name),
           mime_ext: MIME.extensions(mime) |> List.first()
         }}
    end
  end
end
