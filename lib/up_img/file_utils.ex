defmodule FileUtils do
  @moduledoc """
  This module retrieves information about files using the unix command "file".
  It just gives you the files MIME-type in a string representation.
  """

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
        |> Base.encode16()
        |> String.downcase()

      is_binary(path) ->
        :crypto.hash(:sha256, path)
        |> Base.encode16()
        |> String.downcase()

      true ->
        nil
    end
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
