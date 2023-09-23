defmodule UpImg do
  @moduledoc """
  Utilities.
  """
  use UpImgWeb, :verified_routes
  alias UpImg.Accounts

  @rand_size 16
  @hash_algorithm :sha256

  @doc """
  Generates a random secret key of size @rand_size
  """

  def gen_token(length \\ @rand_size) do
    :crypto.strong_rand_bytes(length)
  end

  @doc """
  Create a unique irreversible represention - or hash - of the token.
  """
  def hash_token(token) do
    :crypto.hash(@hash_algorithm, token)
  end

  @doc """
  A random @rand_size string encode in base URL-64
  """
  def gen_secret do
    Base.url_encode64(gen_token(), padding: false)
  end

  @doc """
  Generate a random 8-string
  """
  def gen_salt(length \\ 8) do
    length
    |> :crypto.strong_rand_bytes()
    |> Base.encode64()
    |> String.slice(0, length)
  end

  def shorten(uri) do
    {uri,
     :crypto.mac(:hmac, :sha256, "short-link", uri)
     |> Base.encode16()
     |> String.slice(0, 6)}
  end

  def img_path(name) do
    UpImgWeb.Endpoint.url() <>
      UpImgWeb.Endpoint.static_path("/images/#{name}")
  end

  def fetch_key(main, key),
    do:
      Application.get_application(__MODULE__)
      |> Application.fetch_env!(main)
      |> Keyword.get(key)

  # SHOULD I PUT THEM IN ETS FOR SPEED INSTEAD OF READING ENV VARS?????

  def gh_id, do: fetch_key(:github, :github_client_id)
  def gh_secret, do: fetch_key(:github, :github_client_secret)

  def google_id, do: fetch_key(:google, :google_client_id)
  def google_secret, do: fetch_key(:google, :google_client_secret)

  def vault_key, do: Application.fetch_env!(:up_img, :vault_key)

  def bucket, do: Application.fetch_env!(:ex_aws, :bucket)

  @doc """
  Defines the callback endpoints. It must correspond to the settings in the Google Dev console and Github credentials.
  """
  def google_callback do
    Path.join(
      UpImgWeb.Endpoint.url(),
      Application.get_application(__MODULE__) |> Application.get_env(:google_callback)
    )
  end

  def github_callback do
    Path.join(
      UpImgWeb.Endpoint.url(),
      Application.get_application(__MODULE__) |> Application.get_env(:github_callback)
    )
  end

  def build_path(name) do
    Application.app_dir(:up_img, ["priv", "static", "image_uploads", name])
  end

  def set_image_url(name) do
    UpImgWeb.Endpoint.url() <>
      UpImgWeb.Endpoint.static_path("/image_uploads/#{name}")
  end

  def url_path(name) do
    UpImgWeb.Endpoint.static_path("/image_uploads/#{name}")
  end

  # def home_path(nil = _current_user), do: "/"
  # def home_path(%Accounts.User{} = current_user), do: profile_path(current_user)

  def profile_path(username) when is_binary(username) do
    unverified_path(UpImgWeb.Endpoint, UpImgWeb.Router, ~p"/#{username}")
  end

  def profile_path(%Accounts.User{} = current_user) do
    profile_path(current_user.username)
  end
end
