defmodule UpImg.GsPredict do
  # @model_fb "facebook/deit-base-distilled-patch16-224"

  use GenServer

  def start_link(opts) do
    {:ok, model} = Keyword.fetch(opts, :model)
    GenServer.start_link(__MODULE__, model, name: __MODULE__)
  end

  def serve, do: GenServer.call(__MODULE__, :serving)

  @impl true
  def init(model) do
    {:ok, model, {:continue, :load_model}}
  end

  @impl true
  def handle_continue(:load_model, model) do
    {:ok, resnet} = Bumblebee.load_model({:hf, model})
    {:ok, featurizer} = Bumblebee.load_featurizer({:hf, model})

    {:noreply,
     Bumblebee.Vision.image_classification(resnet, featurizer,
       defn_options: [compiler: EXLA],
       compile: [batch_size: :erlang.system_info(:schedulers_online)]
     )}
  end

  @impl true
  def handle_call(:serving, _from, serving) do
    {:reply, serving, serving}
  end
end
