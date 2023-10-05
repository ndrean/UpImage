defmodule UpImgWeb.GoogleCallbackController do
  use UpImgWeb, :controller
  alias UpImg.Accounts
  require Logger

  def handle(conn, params) when map_size(params) == 0 do
    redirect_home_with_message(conn, "Please try again later")
  end

  def handle(conn, %{"credential" => jwt} = params) do
    with {:ok, profil} <-
           ElixirGoogleCerts.verified_identity(%{jwt: jwt}),
         {:ok, user} <- Accounts.register_google_user(profil) do
      conn
      |> Plug.Conn.fetch_session()
      |> Phoenix.Controller.fetch_flash()
      |> Phoenix.Controller.put_flash(:info, "Welcome #{user.email}")
      |> UpImgWeb.UserAuth.log_in_user(user)
    else
      {:error, %Ecto.Changeset{} = changeset} ->
        Logger.debug("failed Google insert #{inspect(changeset.errors)}")

        redirect_home_with_message(
          conn,
          "We were unable to fetch the necessary information from your Google account"
        )

      {:error, reason} ->
        Logger.debug("failed Google exchange #{inspect(reason)}")
        redirect_home_with_message(conn, "Please try again later")
    end
  end

  def redirect_home_with_message(conn, msg) do
    conn
    |> fetch_session()
    |> fetch_flash()
    |> put_flash(:error, msg)
    |> redirect(to: "/")
  end
end
