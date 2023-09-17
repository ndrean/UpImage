defmodule UpImg.Plug.CheckCsrf do
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
        halt_process(conn, "CSRF cookie missing")

      {_, nil} ->
        halt_process(conn, "CSRF token missing")

      {cookie, param} when cookie != param ->
        halt_process(conn, "CSRF token mismatch")

      _ ->
        IO.puts("ok CSRF---------------")
        conn
    end
  end

  defp halt_process(conn, msg) do
    conn
    |> Phoenix.Controller.fetch_flash()
    |> Phoenix.Controller.put_flash(:error, msg)
    |> Phoenix.Controller.redirect(to: ~p"/")
    |> Plug.Conn.halt()
  end
end
