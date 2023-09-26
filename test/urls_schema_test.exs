defmodule UpImg.Gallery.UrlTest do
  use ExUnit.Case

  alias UpImg.Accounts.User
  alias UpImg.Gallery.Url

  # @valid_google %{
  #   email: "toto@mail.com",
  #   provider: "elysee",
  #   name: "toto",
  #   given_name: "toto Upload"
  # }

  @valid %{
    origin_url: "http://google.com",
    thumb_url: "http://google.com",
    resized_url: "http://google.com",
    key: "key",
    uuid: "1234",
    ext: "png",
    user: %User{}
  }

  describe "changeset/2" do
    changeset = Url.changeset(%Url{}, @valid)
    assert changeset.valid? == false
  end
end
