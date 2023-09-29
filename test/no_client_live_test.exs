defmodule UpImg.NoClientLiveTest do
  import Plug.Conn
  import Phoenix.ConnTest
  import Phoenix.LiveViewTest
  # use UpImg.DataCase, async: false
  use ExUnit.Case
  use UpImgWeb.ConnCase
  alias UpImg.Accounts.User
  alias UpImg.Repo
  @endpoint UpImgWeb.Endpoint

  @valid_google %{
    email: "toto@mail.com",
    provider: "elysee",
    name: "toto",
    given_name: "toto Uploader"
  }

  setup do
    {:ok, conn: Plug.Test.init_test_session(Phoenix.ConnTest.build_conn(), %{})}
    # :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
    # Ecto.Adapters.SQL.Sandbox.mode(Repo, {:shared, self()})
  end

  describe "lv navigation testing" do
    test "redirect to signin if access to uploader", %{conn: conn} do
      conn = get(conn, "/liveview_clientless")
      assert redirected_to(conn) =~ ~p"/signin"
    end

    test "render flash to signin", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/signin", flash: %{"error" => "Please sign in"}}}} ==
               live(conn, "/liveview_clientless")
    end

    setup do
      changeset = User.google_registration_changeset(@valid_google)
      {:ok, %{user: Repo.insert!(changeset)}}
    end

    test "redirect when user registered", %{conn: conn, user: user} do
      conn =
        conn
        |> Plug.Conn.fetch_session()
        |> UpImgWeb.UserAuth.log_in_user(user)

      assert redirected_to(conn) =~ ~p"/"
      assert html_response(conn, 302) =~ "redirected"
      assert conn.assigns.current_user.id == user.id
    end

    test "check LV mount when registered user", %{conn: conn, user: user} do
      conn =
        conn
        |> put_session(:user_id, user.id)
        |> put_session(:live_socket_id, "users_sessions:#{user.id}")
        |> assign(:current_user, user)

      assert conn.assigns.current_user.id == user.id
      assert get_session(conn, :user_id) == user.id

      get(conn, "/liveview_clientless")

      {:ok, _view, html} = live(conn, "/liveview_clientless")
      assert html =~ "The images below are temporarilly saved on the server"

      upload_dir =
        Application.app_dir(:up_img, ["priv", "static", "image_uploads"])
        |> File.exists?()

      assert upload_dir == true
    end

    test "welcome not registered and navigate to signin", %{conn: conn} do
      {:ok, view, html} = live(conn, "/welcome")
      assert html =~ " Quick sign-in"

      assert view |> element("#signin-link") |> render_click() ==
               {:error, {:redirect, %{to: "/signin"}}}
    end

    test "welcome registered and navigate to uploader", %{conn: conn, user: user} do
      conn =
        conn
        |> put_session(:user_id, user.id)
        |> put_session(:live_socket_id, "users_sessions:#{user.id}")
        |> assign(:current_user, user)

      {:ok, view, html} = live(conn, "/welcome")
      assert html =~ "Go to files upload"

      assert view |> element("#to-uploader") |> render_click() ==
               {:error, {:live_redirect, %{kind: :push, to: "/liveview_clientless"}}}
    end

    test "welcome to logout", %{conn: conn, user: user} do
      conn =
        conn
        |> put_session(:user_id, user.id)
        |> put_session(:live_socket_id, "users_sessions:#{user.id}")
        |> assign(:current_user, user)

      {:ok, view, _html} = live(conn, "/welcome")

      assert view |> element("#signout") |> render_click() ==
               {:error, {:redirect, %{to: "/signout"}}}
    end

    test "logout. check redirection & current_user is wipped out", %{conn: conn, user: user} do
      conn =
        conn
        |> put_session(:user_id, user.id)
        |> put_session(:live_socket_id, "users_sessions:#{user.id}")
        |> assign(:current_user, user)

      conn = delete(conn, "/signout", current_user: user)
      assert redirected_to(conn) =~ ~p"/"

      assert %{"current_user" => %User{} = user} == conn.params
    end

    test "signin page", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/signin")
      assert html =~ "Create or Sign in to your account"
    end
  end
end
