defmodule UpImgWeb.RedirectController do
  use UpImgWeb, :controller

  # uses the Plug.fetch_user
  def redirect_authenticated(conn, _params) do
    redirect(conn, to: ~p"/welcome")
  end
end
