defmodule UpImgWeb.RedirectController do
  use UpImgWeb, :controller

  import UpImgWeb.UserAuth, only: [fetch_current_user: 2]
  plug :fetch_current_user

  def redirect_authenticated(conn, _params) do
    if conn.assigns.current_user do
      UpImgWeb.UserAuth.redirect_if_user_is_authenticated(conn, [])
    else
      redirect(conn, to: ~p"/signin")
    end
  end
end
