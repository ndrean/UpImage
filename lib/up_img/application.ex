defmodule UpImg.Application do
  @moduledoc false

  use Application
  # @model_fb "facebook/deit-base-distilled-patch16-224"
  # @model_mn "microsoft/resnet-50"

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
      {GenMagic.Server, name: :gen_magic},
      # {UpImg.GsPredict, [model: System.fetch_env!("MODEL")]}
      {Nx.Serving, serving: serve(), name: UpImg.Serving, batch_size: 10, batch_timeout: 100}
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

  def serve() do
    model = System.fetch_env!("MODEL")
    {:ok, resnet} = Bumblebee.load_model({:hf, model})
    {:ok, featurizer} = Bumblebee.load_featurizer({:hf, model})

    Bumblebee.Vision.image_classification(resnet, featurizer,
      defn_options: [compiler: EXLA],
      top_k: 1,
      compile: [batch_size: 10]
    )
  end
end
