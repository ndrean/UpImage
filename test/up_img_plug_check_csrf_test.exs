defmodule UpImgPlugCheckCsrfTest do
  use ExUnit.Case, async: true
  # use Plug.Test
  use UpImgWeb.ConnCase

  # @session Plug.Session.init(
  #            store: :cookie,
  #            key: :up_img,
  #            encryption_salt: "yadayada",
  #            signing_salt: "yadayada",
  #            secret_key_base: String.duplicate("a", 64)
  #          )

  # setup do
  #   conn =
  #     conn(:get, "/")
  #     |> Map.put(:g_crsf_token, "toto")
  #     |> Plug.Session.call(@session)
  #     |> Plug.Conn.fetch_session()
  #     |> Map.replace!(:cookies, %{g_csrf_token: "cookie"})

  #   {:ok, conn: conn}
  # end

  test "it halts the process when CSRF cookie is missing", %{conn: conn} do
    # conn =
    #   conn(:get, "/")
    #   |> put_session(:cookies, %{g_csrf_token: "cookie"})
    #   |> put_req_cookie("g_csrf_token", "toto")

    conn =
      UpImg.Plug.CheckCsrf.call(conn, %{g_csrf_token: "toto"})

    # |> Plug.Conn.fetch_session()
    # |> Plug.Conn.put_session(:g_crsf_token, "mycookie")
    # |> Router.call(@opts)
    # # |> put_resp_cookie("g_csrf_token", "mycookie")
    # |> UpImg.Plug.CheckCsrf.call({})

    assert conn.assigns.cookies["g_crsf_token"] == "mycookie"
    # assert get_flash(conn, :error) == "CSRF cookie missing"
  end

  # test "it halts the process when CSRF token is missing" do
  #   conn =
  #     conn(:get, "/welcome")
  #     |> put_req_cookie("g_csrf_token", "some_value")
  #     |> UpImg.Plug.CheckCsrf.call(%{})

  #   assert redirected_to(conn) == "/"
  #   assert get_flash(conn, :error) == "CSRF token missing"
  # end

  # test "it halts the process when CSRF token mismatch" do
  #   conn =
  #     conn()
  #     |> put_req_cookie("g_csrf_token", "cookie_value")
  #     |> put_req_param("g_csrf_token", "param_value")
  #     |> UpImg.Plug.CheckCsrf.call(%{})

  #   assert redirected_to(conn) == "/"
  #   assert get_flash(conn, :error) == "CSRF token mismatch"
  # end

  # test "it continues the process when CSRF is valid" do
  #   conn =
  #     conn()
  #     |> put_req_cookie("g_csrf_token", "cookie_value")
  #     |> put_req_param("g_csrf_token", "cookie_value")
  #     |> UpImg.Plug.CheckCsrf.call(%{})

  #   assert conn.status == 200
  #   assert get_flash(conn, :error) == nil
  # end
end
