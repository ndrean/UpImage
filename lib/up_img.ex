defmodule UpImg do
  @moduledoc """
  Utilities.
  """
  use UpImgWeb, :verified_routes
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
end
