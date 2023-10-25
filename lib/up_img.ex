defmodule UpImg do
  @moduledoc """
  Utilities.
  """
  use UpImgWeb, :verified_routes
  alias Vix.Vips.Image
  # alias UpImg.Accounts

  @rand_size 8

  @doc """
  A random @rand_size string encode in base URL-64
  """
  def gen_secret(length \\ @rand_size) do
    :crypto.strong_rand_bytes(length)
    |> Base.url_encode64()
  end

  def img_path(name) do
    UpImgWeb.Endpoint.url() <>
      UpImgWeb.Endpoint.static_path("/images/#{name}")
  end

  def vault_key, do: Application.fetch_env!(:up_img, :vault_key)
  def env, do: Application.fetch_env!(:up_img, :env)

  @doc """
  Defines the callback endpoints. It must correspond to the settings in the Google Dev console and Github credentials.
  """

  def google_callback do
    Path.join(
      UpImgWeb.Endpoint.url(),
      Application.get_application(__MODULE__) |> Application.get_env(:google_callback)
    )
  end

  def build_path(name) do
    Application.app_dir(:up_img, ["priv", "static", "image_uploads", name])
  end

  def quick_clean(older_than_minutes: time_min) do
    require Logger
    :ok = Logger.info("force clean ---")

    Application.app_dir(:up_img, ["priv", "static", "image_uploads"])
    |> File.ls!()
    |> Enum.map(&UpImg.build_path/1)
    |> Enum.filter(fn file ->
      %File.Stat{atime: t} = File.stat!(file, time: :posix)
      last_read_date = DateTime.from_unix!(t) |> dbg()
      time_target = DateTime.utc_now() |> DateTime.add(-time_min, :minute)
      DateTime.compare(last_read_date, time_target) == :lt
    end)
    |> Enum.each(&File.rm_rf!/1)
  end

  @doc """
  Give a path containing an image, runs an Image-To-Text task against a model.

  The model is started in the Application.ex module.
  """
  def run_prediction_task(path) do
    {:ok, image} = Image.new_from_file(path)

    {:ok, %Vix.Tensor{data: data, shape: shape, names: names, type: type}} =
      Image.write_to_tensor(image)

    t_image = Nx.from_binary(data, type) |> Nx.reshape(shape, names: names)

    Task.Supervisor.async_nolink(UpImg.TaskSup, fn ->
      Nx.Serving.batched_run(UpImg.Serving, t_image)
    end)
  end
end
