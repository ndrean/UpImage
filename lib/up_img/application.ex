defmodule UpImg.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    hour_s = 60 * 60
    hour_ms = hour_s * 1000

    children = [
      UpImgWeb.Telemetry,
      UpImg.Repo,
      {Phoenix.PubSub, name: UpImg.PubSub},
      {Finch, name: UpImg.Finch},
      UpImgWeb.Endpoint,
      UpImg.MyVault,
      {Task.Supervisor, name: UpImg.TaskSup},
      {UpImg.EnvReader, {}},
      {Task,
       fn ->
         FileUtils.clean(every_ms: hour_ms, older_than_seconds: hour_s)
       end}
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

  def read_env do
    IO.puts("done")
    System.fetch_env!("GOOGLE_CLIENT_ID")
  end
end
