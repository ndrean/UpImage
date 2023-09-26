defmodule UpImg.Accounts.UserTest do
  # use ExUnit.Case
  use UpImg.DataCase, async: false

  alias UpImg.Accounts.User
  alias UpImg.Repo

  @valid_google %{
    email: "toto@mail.com",
    provider: "elysee",
    name: "toto",
    given_name: "toto Upload"
  }

  @valid_github %{
    "email" => "toto-#{System.unique_integer([:positive])}@mail.com",
    "provider" => "github",
    "name" => "toto",
    "login" => "toto Upload #{System.unique_integer([:positive])}"
  }

  @invalid %{}

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
    # Ecto.Adapters.SQL.Sandbox.mode(Repo, {:shared, self()})
  end

  describe "google_registration_changeset/1" do
    test "google valid changeset" do
      changeset = User.google_registration_changeset(@valid_google)
      assert changeset.valid? == true
    end

    test "google invalid changeset" do
      changeset = User.google_registration_changeset(@invalid)
      assert changeset.valid? == false
    end
  end

  describe "github_registration_changeset/1" do
    test "github valid changeset" do
      changeset = User.github_registration_changeset(@valid_github)
      assert changeset.valid? == true
    end

    test "github invalid changeset" do
      changeset = User.github_registration_changeset(@invalid)
      assert changeset.valid? == false
    end
  end

  describe "insert user" do
    test "register_google_user" do
      changeset = User.google_registration_changeset(@valid_google)
      {:ok, user} = Repo.insert(changeset)

      assert Repo.one(User).username == user.username
    end
  end
end
