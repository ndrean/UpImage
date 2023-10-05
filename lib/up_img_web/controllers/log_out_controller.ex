defmodule UpImgWeb.LogOutController do
  use UpImgWeb, :controller

  def sign_out(conn, _p) do
    UpImgWeb.UserAuth.log_out_user(conn)
  end
end
