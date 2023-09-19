defmodule UpImgWeb.Plug.FetchUser do
  @moduledoc """
  Plug: authenticates the user by looking into the session. Assigns a `:current_user`  (nil or found).
  """
  def init(opts), do: opts

  def call(conn, _opts) do
    user_id = Plug.Conn.get_session(conn, :user_id)
    user = user_id && UpImg.Accounts.get_user(user_id)

    Plug.Conn.assign(conn, :current_user, user)
  end
end
