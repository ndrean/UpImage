defmodule UpImgPlugCheckCsrfTest do
  use ExUnit.Case
  use UpImgWeb.ConnCase


  test "it halts the process when CSRF cookie is missing", %{conn: conn} do

    assert redirected_to(conn) == "/"
    # assert get_flash(conn, :error) == "CSRF cookie missing"
  end

  # test "it halts the process when CSRF token is missing" do
  #   conn =
  #     conn()
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
