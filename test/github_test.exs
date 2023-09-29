defmodule UpImgGithubTest do
  use ExUnit.Case

  alias UpImg.Github

  describe "initialisations" do
    test "env vars" do
      assert Github.client_id() == "GITHUB_CLIENT_ID"
      assert Github.secret() == "GITHUB_CLIENT_SECRET"

      authorized_url =
        "https://github.com/login/oauth/authorize?state=state&client_id=GITHUB_CLIENT_ID&scope=user%3Aemail"

      assert Github.authorize_url() == authorized_url
    end
  end
end
