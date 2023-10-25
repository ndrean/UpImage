defmodule UpImg.EnvReader do
  @moduledoc """
  Task to load in an ETS table the env variables
  """
  use Task

  def start_link(arg) do
    :envs = :ets.new(:envs, [:set, :public, :named_table])
    Task.start_link(__MODULE__, :run, [arg])
  end

  def run(_arg) do
    :ets.insert(:envs, {:google_id, read_google_id()})
    :ets.insert(:envs, {:gh_id, read_gh_id()})
    :ets.insert(:envs, {:gh_secret, read_gh_secret()})
    :ets.insert(:envs, {:google_secret, read_google_secret()})
    :ets.insert(:envs, {:cleaning_timer, read_cleaning_timer()})
    :ets.insert(:envs, {:my_env, read_env()})
    :ets.insert(:envs, {:upload_limit, read_upload_limit()})
    # AWS/B2
    :ets.insert(:envs, {:bucket, read_bucket()})
    :ets.insert(:envs, {:endpoint, read_endpoint()})
    :ets.insert(:envs, {:bucket_key_id, read_bucket_key_id()})
    :ets.insert(:envs, {:bucket_secret, read_bucket_secret()})
    # :ets.insert(:envs, {:bucket_region, read_bucket_region()})
    :ets.insert(:envs, {:bucket_host, read_bucket_host()})
  end

  defp fetch_app_key(app \\ __MODULE__, main, key),
    do:
      Application.get_application(app)
      |> Application.fetch_env!(main)
      |> Keyword.fetch!(key)

  defp fetch_lib_key(lib, main, key) do
    lib
    |> Application.fetch_env!(main)
    |> Keyword.fetch!(key)
  end

  defp lookup(key), do: :ets.lookup(:envs, key) |> Keyword.get(key)

  defp read_gh_id, do: fetch_app_key(:github, :github_client_id)
  defp read_gh_secret, do: fetch_app_key(:github, :github_client_secret)
  defp read_google_id, do: fetch_app_key(:google, :google_client_id)
  defp read_google_secret, do: fetch_app_key(:google, :google_client_secret)

  defp read_env, do: Application.fetch_env!(:up_img, :env)
  defp read_upload_limit, do: Application.fetch_env!(:up_img, :upload_limit)

  defp read_bucket, do: fetch_lib_key(:ex_aws, :s3, :bucket)
  defp read_endpoint, do: fetch_lib_key(:ex_aws, :s3, :host)
  defp read_bucket_key_id, do: fetch_lib_key(:ex_aws, :s3, :access_key_id)
  defp read_bucket_secret, do: fetch_lib_key(:ex_aws, :s3, :secret_access_key)
  # defp read_bucket_region, do: fetch_lib_key(:ex_aws, :s3, :region)
  defp read_bucket_host, do: fetch_lib_key(:ex_aws, :s3, :host)

  defp read_cleaning_timer, do: Application.fetch_env!(:up_img, :cleaning_timer)

  # Lookups from ETS

  def google_id, do: lookup(:google_id)
  def google_secret, do: lookup(:google_secret)

  def gh_id, do: lookup(:gh_id)
  def gh_secret, do: lookup(:gh_secret)

  def cleaning_timer, do: lookup(:cleaning_timer)
  def get_env, do: lookup(:my_env)
  def upload_limit, do: lookup(:upload_limit)

  def bucket_secret, do: lookup(:bucket_secret)
  def bucket_key_id, do: lookup(:bucket_key_id)
  # def bucket_region, do: lookup(:bucket_region)
  def bucket_host, do: lookup(:bucket_host)
  def bucket, do: lookup(:bucket)
  def endpoint, do: lookup(:endpoint)
end
