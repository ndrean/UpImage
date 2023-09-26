defmodule UpImg.ChunkWriter do
  @moduledoc """
  Sends file in memory and not written in a temp dir.
  """
  @behaviour Phoenix.LiveView.UploadWriter
  require Logger

  @impl true
  def init(_opts) do
    {:ok, %{file: ""}}
  end

  # it sends back the "meta"
  @impl true
  def meta(state), do: state

  @impl true
  def write_chunk(chunk, state) do
    {:ok, Map.update!(state, :file, &(&1 <> chunk))}
  end

  @impl true
  def close(state, :done) do
    {:ok, state}
  end

  def close(state, reason) do
    Logger.error("Error writer-----#{inspect(reason)}")
    {:ok, Map.put(state, :errors, inspect(reason))}
  end
end
