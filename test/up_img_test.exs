defmodule UpImgTest do
  use ExUnit.Case

  # describe "test gen_secret/1" do
  #   assert UpImg.gen_secret() |> Base.url_decode64!() |> String.length() == 8
  # end

  describe "test img_path/1" do
    assert UpImg.img_path("toto") == "http://localhost:4002/images/toto"
  end

  describe "test google_callback/0" do
    assert UpImg.google_callback() == "http://localhost:4002/google/callback"
  end

  describe "test buid_path/1" do
    result = (:code.priv_dir(:up_img) |> to_string) <> "/static/image_uploads/toto"
    assert UpImg.build_path("toto") == result
  end

  describe "vault_key/0" do
    assert UpImg.vault_key() == "CLOAKKEY"
  end
end
