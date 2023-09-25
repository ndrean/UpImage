defmodule UpImgGithubTest do
  use ExUnit.Case

  alias UpImg.Github

  test "1" do
    assert Github.client_id() == "GITHUB_CLIENT_ID"
    assert Github.secret() == "GITHUB_CLIENT_SECRET"
  end
end
