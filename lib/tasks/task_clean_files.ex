defmodule UpImg.CleanFiles do
  @moduledoc """
  Utility to clean old files on the server
  """
  use Task
  require Logger

  def start_link(_arg) do
    period = System.fetch_env!("PERIOD")
    Task.start_link(__MODULE__, :run, [period])
  end

  def run(period) do
    hour_s = 60 * 60 * String.to_integer(period)
    hour_ms = hour_s * 1000
    clean(every_ms: hour_ms, older_than_seconds: hour_s)
  end

  def clean(every_ms: interval, older_than_seconds: time_s) do
    :ok = Process.sleep(interval)
    :ok = Logger.info("force clean ---")

    Application.app_dir(:up_img, ["priv", "static", "image_uploads"])
    |> File.ls!()
    |> Enum.map(&UpImg.build_path/1)
    |> Enum.filter(fn file ->
      %File.Stat{atime: t} = File.stat!(file, time: :posix)
      t < System.monotonic_time(:second) - time_s
    end)
    |> Enum.each(&File.rm_rf!/1)

    clean(every_ms: interval, older_than_seconds: time_s)
  end
end
