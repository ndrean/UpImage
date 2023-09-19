defmodule UpImg.Plug.CheckCsrf do
  @moduledoc """
  Plug to check the CSRF state concordance when receiving data from Google.

  Denies to treat the HTTP request if fails.
  """
  use UpImgWeb, :verified_routes
  def init(opts), do: opts

  def call(conn, _opts) do
    g_csrf_from_cookies =
      Plug.Conn.fetch_cookies(conn)
      |> Map.get(:cookies, %{})
      |> Map.get("g_csrf_token")

    g_csrf_from_params =
      Map.get(conn.params, "g_csrf_token")

    case {g_csrf_from_cookies, g_csrf_from_params} do
      {nil, _} ->
        # test ok
        halt_process(conn, "CSRF cookie missing")

      {_, nil} ->
        # test ok
        halt_process(conn, "CSRF token missing")

      {cookie, param} when cookie != param ->
        # test ok
        halt_process(conn, "CSRF token mismatch")

      _ ->
        # test ok
        conn
    end
  end

  defp halt_process(conn, msg) do
    # test ok
    conn
    |> Plug.Conn.fetch_session()
    |> Phoenix.Controller.fetch_flash()
    |> Phoenix.Controller.put_flash(:error, msg)
    |> Phoenix.Controller.redirect(to: ~p"/")
    |> Plug.Conn.halt()
  end
end
