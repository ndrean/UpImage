defmodule UpImg.EnvReaderTest do
  use ExUnit.Case
  alias UpImg.EnvReader

  setup_all do
    # Initialize and populate the ETS table with sample data
    :ets.insert(:envs, {:google_id, "GOOGLE_CLIENT_ID"})
    :ets.insert(:envs, {:gh_id, "GITHUB_CLIENT_ID"})
    :ets.insert(:envs, {:gh_secret, "GITHUB_CLIENT_SECRET"})
    :ets.insert(:envs, {:google_secret, "GOOGLE_CLIENT_SECRET"})
    :ets.insert(:envs, {:bucket, "AWS_S3_BUCKET"})
    :ets.insert(:envs, {:cleaning_timer, 120_000})
    :ets.insert(:envs, {:vault_key, "CLOAKKEY"})
    :ok
  end

  test "table :envs exists" do
    assert :ets.whereis(:envs) != nil
  end

  test "accessors retrieve values from the ETS table" do
    assert EnvReader.bucket() == "AWS_S3_BUCKET"
    assert EnvReader.google_id() == "GOOGLE_CLIENT_ID"
    assert EnvReader.google_secret() == "GOOGLE_CLIENT_SECRET"
    assert EnvReader.gh_id() == "GITHUB_CLIENT_ID"
    assert EnvReader.gh_secret() == "GITHUB_CLIENT_SECRET"
  end

  test "accessors retrived with Application.fetch_env!/2" do
    assert EnvReader.cleaning_timer() == 120_000
  end

  :ets.delete(:envs, :bucket)
  :ets.delete(:envs, :gh_id)
  :ets.delete(:envs, :gh_secret)
  :ets.delete(:envs, :google_id)
  :ets.delete(:envs, :google_secret)
  :ets.delete(:envs, :cleaning_timer)
  :ets.delete(:envs, :vault_key)
end
