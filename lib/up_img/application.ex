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
      UpImg.EnvReader,
      UpImg.CleanFiles,
      {GenMagic.Server, name: :gen_magic}
      # {GenMagic.Pool.NimblePool, pool_name: MagicPool, pool_size: 2}
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
end
