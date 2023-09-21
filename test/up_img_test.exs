defmodule UpImgTest do
  use ExUnit.Case

  describe "img_path/1" do
    test "returns the correct image path" do
      expected = "http://localhost:4002/images/example.png"
      assert UpImg.img_path("example.png") == expected
    end
  end

  describe "fetch_key/2" do
    test "fetches the correct value" do
      expected = "GITHUB_CLIENT_ID"
      assert UpImg.fetch_key(:github, :github_client_id) == expected
    end

    test "raises an error when the key is not found" do
      assert_raise ArgumentError, fn ->
        UpImg.fetch_key(:up_img, :vault_key)
      end
    end
  end

  describe "gh_id/0" do
    test "returns the GitHub client ID" do
      expected = "GITHUB_CLIENT_ID"
      assert UpImg.gh_id() == expected
    end
  end

  describe "gh_secret/0" do
    test "returns the GitHub client secret" do
      expected = "GITHUB_CLIENT_SECRET"
      assert UpImg.gh_secret() == expected
    end
  end

  describe "google_id/0" do
    test "returns the Google client ID" do
      expected = "GOOGLE_CLIENT_ID"
      assert UpImg.google_id() == expected
    end
  end

  describe "google_secret/0" do
    test "returns the Google client secret" do
      expected = "GOOGLE_CLIENT_SECRET"
      assert UpImg.google_secret() == expected
    end
  end

  describe "vault_key/0" do
    test "returns the vault key" do
      expected = "CLOAKKEY"
      assert UpImg.vault_key() == expected
    end
  end

  describe "bucket/0" do
    test "returns the bucket name" do
      expected = "AWS_S3_BUCKET"
      assert UpImg.bucket() == expected
    end
  end
end
