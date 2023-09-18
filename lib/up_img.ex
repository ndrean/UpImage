defmodule UpImg do
  @moduledoc """
  Utilities.
  """
  use UpImgWeb, :verified_routes
  alias UpImg.Accounts

  @rand_size 16
  @hash_algorithm :sha256

  @doc """
  Generates a random base64 encoded secret key.
  """

  def gen_token do
    :crypto.strong_rand_bytes(@rand_size)
  end

  def hash_token(token) do
    :crypto.hash(@hash_algorithm, token)
  end

  def gen_secret do
    Base.url_encode64(gen_token(), padding: false)
  end

  @doc """
  Looks up `Application` config or raises if keyspace is not configured.

  ## Examples

      config :my_app, :files, [
        uploads_dir: Path.expand("../priv/uploads", __DIR__),
        host: [scheme: "http", host: "localhost", port: 4000],
      ]

      iex> MyApp.config([:files, :uploads_dir])
      iex> MyApp.config([:files, :host, :port])
  """
  def config([main_key | rest] = keyspace) when is_list(keyspace) do
    main = Application.fetch_env!(Application.get_application(__MODULE__), main_key)

    Enum.reduce(rest, main, fn next_key, current ->
      case Keyword.fetch(current, next_key) do
        {:ok, val} -> val
        :error -> raise ArgumentError, "no config found under #{inspect(keyspace)}"
      end
    end)
  end

  # for a non nested simple case, you can do:
  def config([main, second]) do
    case Application.get_application(__MODULE__)
         |> Application.fetch_env!(main)
         |> Keyword.get(second) do
      nil -> raise "No config found for: #{main}, #{second}"
      res -> res
    end
  end

  def img_path(name) do
    UpImgWeb.Endpoint.url() <>
      UpImgWeb.Endpoint.static_path("/images/#{name}")
  end

  def google_client_id, do: config([:google, :client_id])

  @doc """
  Defines the Google callback endpoint. It must correspond to the settings in the Google Dev console.
  """
  def google_callback do
    Path.join(
      UpImgWeb.Endpoint.url(),
      Application.get_application(__MODULE__) |> Application.get_env(:google_callback)
    )
  end

  def bucket do
    Application.get_env(:ex_aws, :bucket)
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
