defmodule UpImgWeb.LogOutController do
  use UpImgWeb, :controller

  def sign_out(conn, _) do
    UpImgWeb.UserAuth.log_out_user(conn)
  end
end
