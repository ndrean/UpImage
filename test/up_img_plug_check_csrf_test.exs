defmodule UpImgPlugCheckCsrfTest do
  use ExUnit.Case, async: true
  # use Plug.Test
  use UpImgWeb.ConnCase
  import Plug.Conn
  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  @endpoint UpImgWeb.Endpoint

  setup do
    {:ok, conn: Plug.Test.init_test_session(Phoenix.ConnTest.build_conn(), %{})}
  end

  test "route: /, should redirect to /welcome and set current_user to nil", %{conn: conn} do
    conn = get(conn, "/")

    assert conn.assigns.current_user == nil
    assert html_response(conn, 302) =~ "redirected"
  end

  test "route /welcome", %{conn: conn} do
    {:ok, lv, _html} = live(conn, "/welcome")
    assert render(lv) =~ "WEBP"
  end

  test "/google/callback with failing cookie", %{conn: conn} do
    conn =
      conn
      |> get("/")
      |> post("/google/callback", %{
        "credentials" => "superjwt"
      })

    assert fetch_flash(conn).assigns.flash["error"] == "CSRF cookie missing"

    %{halted: halted} = conn
    assert halted == true
  end

  test "/google/callback with failing token", %{conn: conn} do
    conn =
      conn
      |> put_req_cookie("g_csrf_token", "my very long cookie")
      |> get("/")
      |> Plug.Conn.fetch_session()
      |> post("/google/callback", %{
        "credentials" => "superjwt"
      })

    assert fetch_flash(conn).assigns.flash["error"] == "CSRF token missing"

    %{halted: halted} = conn
    assert halted == true
  end

  test "/google/callback with mistmatch token", %{conn: conn} do
    conn =
      conn
      |> put_req_cookie("g_csrf_token", "my very long cookie")
      |> get("/")
      |> Plug.Conn.fetch_session()
      |> post("/google/callback", %{
        "credentials" => "superjwt",
        "g_csrf_token" => "not the same"
      })

    assert fetch_flash(conn).assigns.flash["error"] == "CSRF token mismatch"

    %{halted: halted} = conn
    assert halted == true
  end

  test "continues the process when CSRF is valid", %{conn: conn} do
    conn =
      conn
      |> put_req_cookie("g_csrf_token", "my very long cookie")
      |> get("/")
      |> Plug.Conn.fetch_session()

    %{assigns: %{flash: flash}} = Phoenix.Controller.fetch_flash(conn)

    assert flash == %{}
    assert conn.status == 302
  end
end
