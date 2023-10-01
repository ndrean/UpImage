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
end
