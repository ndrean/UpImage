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
    :ets.insert(:envs, {:bucket, read_bucket()})
    :ets.insert(:envs, {:cleaning_timer, read_cleaning_timer()})
  end

  def fetch_key(main, key),
    do:
      Application.get_application(__MODULE__)
      |> Application.fetch_env!(main)
      |> Keyword.get(key)

  def lookup(key), do: :ets.lookup(:envs, key) |> Keyword.get(key)

  # SHOULD I PUT THEM IN ETS FOR SPEED INSTEAD OF READING ENV VARS?????

  def read_gh_id, do: fetch_key(:github, :github_client_id)
  def read_gh_secret, do: fetch_key(:github, :github_client_secret)
  def read_google_id, do: fetch_key(:google, :google_client_id)
  def read_google_secret, do: fetch_key(:google, :google_client_secret)
  def read_vault_key, do: Application.fetch_env!(:up_img, :vault_key)
  def read_bucket, do: Application.fetch_env!(:ex_aws, :bucket)

  def read_cleaning_timer, do: Application.fetch_env!(:up_img, :cleaning_timer)

  # Lookups
  def bucket, do: lookup(:bucket)

  def google_id, do: lookup(:google_id)

  def google_secret, do: lookup(:google_secret)

  def gh_id, do: lookup(:gh_id)

  def gh_secret, do: lookup(:gh_secret)

  def cleaning_timer, do: lookup(:cleaning_timer)
end
