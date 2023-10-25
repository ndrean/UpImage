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
    interval = 1000 * 60 * String.to_integer(period)
    time_min = 5
    clean(every_h: interval, older_than_minutes: time_min)
  end

  def clean(every_h: interval, older_than_minutes: time_min) do
    :ok = Process.sleep(interval)
    :ok = Logger.info("force clean ---")

    :ok =
      Application.app_dir(:up_img, ["priv", "static", "image_uploads"])
      |> File.ls!()
      |> Enum.map(&UpImg.build_path/1)
      |> Enum.filter(fn file ->
        %File.Stat{atime: t} = File.stat!(file, time: :posix)
        last_read_date = DateTime.from_unix!(t)
        time_target = DateTime.utc_now() |> DateTime.add(-time_min, :minute)
        DateTime.compare(last_read_date, time_target) == :lt
      end)
      |> Enum.each(&File.rm_rf!/1)

    clean(every_h: interval, older_than_minutes: time_min)
  end
end
