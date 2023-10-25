defmodule FileUtils do
  @moduledoc """
  This module retrieves information about files using the unix command "file".
  It just gives you the files MIME-type in a string representation.
  """
  require Logger

  @doc """
  Given a name, it copies a file at a given path into a new in the "priv/Static/image_uploads" folder.
  """
  def copy_path_into(path, name) do
    tmp_path = UpImg.build_path(name)

    path
    |> File.stream!([], 64_000)
    |> Stream.into(File.stream!(tmp_path))
    |> Stream.run()

    tmp_path
  end

  def hash_file(%{path: path} = image) when is_map(image) do
    {:ok, FileUtils.sha256(path) <> ".webp"}
  rescue
    e in File.Error ->
      Logger.error(inspect(e.reason))
      {:error, :file_error}
  end

  @doc """
  Hash of a file
  """
  def sha256(path) when is_binary(path) do
    case File.exists?(path) do
      true ->
        File.stream!(path, [], 2048)
        |> Enum.reduce(:crypto.hash_init(:sha256), fn curr_chunk, prev ->
          :crypto.hash_update(prev, curr_chunk)
        end)
        |> :crypto.hash_final()
        |> terminate()

      false ->
        nil
    end
  end

  @doc """
  HMAC hash used to produce a short name
  """
  def terminate(string) when is_binary(string) do
    :crypto.macN(:hmac, :sha256, "tiny URL", string, 16)
    |> Base.encode16()
    |> String.slice(0, 8)
  end

  # def info(names) when is_list(names) do
  #   Enum.map(names, &info(&1))
  # end

  # def info(name) when is_binary(name) do
  #   case File.exists?(name) do
  #     false ->
  #       {:error, "File does not exist"}

  #     true ->
  #       {result, 0} = System.cmd("file", ["--mime-type" | [name]])

  #       [n, mime] =
  #         result
  #         |> String.split("\n")
  #         |> Stream.filter(&(&1 !== ""))
  #         |> Stream.map(&String.split(&1, ": "))
  #         |> Enum.into([])
  #         |> List.flatten()

  #       {:ok,
  #        %{
  #          short_name: Path.basename(n),
  #          type: mime,
  #          path: name,
  #          displayed_ext: Path.extname(name),
  #          mime_ext: MIME.extensions(mime) |> List.first()
  #        }}
  #   end
  # end
end
