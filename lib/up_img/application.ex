defmodule UpImg.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Start the Telemetry supervisor
      UpImgWeb.Telemetry,
      # Start the Ecto repository
      UpImg.Repo,
      # Start the PubSub system
      {Phoenix.PubSub, name: UpImg.PubSub},
      # Start Finch
      {Finch, name: UpImg.Finch},
      # Start the Endpoint (http/https)
      UpImgWeb.Endpoint,
      UpImg.MyVault
      # Start a worker by calling: UpImg.Worker.start_link(arg)
      # {UpImg.Worker, arg}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: UpImg.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    UpImgWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
