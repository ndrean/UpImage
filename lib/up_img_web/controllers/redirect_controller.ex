defmodule UpImgWeb.RedirectController do
  use UpImgWeb, :controller

  # uses the Plug.fetch_user
  def redirect_authenticated(conn, _params) do

    if Map.get(conn.assigns, :current_user) do
      redirect(conn, to: ~p"/#{conn.assigns.current_user.name}")
      |> halt()
    else
      redirect(conn, to: ~p"/welcome")
    end
  end
end
