defmodule UpImg.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      UpImgWeb.Telemetry,
      UpImg.Repo,
      {Phoenix.PubSub, name: UpImg.PubSub},
      {Finch, name: UpImg.Finch},
      UpImgWeb.Endpoint,
      UpImg.MyVault,
      {Task.Supervisor, name: UpImg.TaskSup},
      {Task, fn -> clean(every: 6 * 60 * 1_000) end}
    ]

    opts = [strategy: :one_for_one, name: UpImg.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    UpImgWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  def clean(every: interval) do
    Process.sleep(interval)

    Application.app_dir(:up_img, ["priv", "static", "image_uploads"])
    |> File.ls!()
    |> Enum.map(&UpImg.build_path/1)
    |> Enum.filter(fn file ->
      %File.Stat{atime: t} = File.stat!(file, time: :posix)
      t < System.os_time(:second) - 60 * 60 * 6
    end)
    |> Enum.each(&File.rm_rf!/1)

    clean(every: interval)
  end
end
