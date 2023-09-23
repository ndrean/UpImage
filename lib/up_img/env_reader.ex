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
    :ets.insert(:envs, {:google_id, UpImg.google_id()})
    :ets.insert(:envs, {:gh_id, UpImg.gh_id()})
    :ets.insert(:envs, {:gh_secret, UpImg.gh_secret()})
    :ets.insert(:envs, {:google_secret, UpImg.google_secret()})
    :ets.insert(:envs, {:bucket, UpImg.bucket()})

    :ets.insert(:envs, {:cleaning_timer, Application.fetch_env!(:up_img, :cleaning_timer)})
  end

  def bucket, do: :ets.lookup(:envs, :bucket) |> Keyword.get(:bucket)

  def google_id, do: :ets.lookup(:envs, :google_id) |> Keyword.get(:google_id)

  def google_secret, do: :ets.lookup(:envs, :google_secret) |> Keyword.get(:google_secret)

  def gh_id, do: :ets.lookup(:envs, :gh_id) |> Keyword.get(:gh_id)

  def gh_secret, do: :ets.lookup(:envs, :gh_secret) |> Keyword.get(:gh_secret)

  def cleaning_timer, do: :ets.lookup(:envs, :cleaning_timer) |> Keyword.get(:cleaning_timer)
end
