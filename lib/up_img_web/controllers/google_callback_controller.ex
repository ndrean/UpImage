defmodule UpImgWeb.GoogleCallbackController do
  use UpImgWeb, :controller
  alias UpImg.Accounts
  require Logger

  def handle(conn, %{"credential" => credential}) do
    with {:ok, profil} <-
           ElixirGoogleCerts.verified_identity(%{jwt: credential}),
         {:ok, user} <- Accounts.register_google_user(profil) do
      conn
      |> Plug.Conn.fetch_session()
      |> Phoenix.Controller.fetch_flash()
      |> put_flash(:info, "Welcome #{user.email}")
      |> UpImgWeb.UserAuth.log_in_user(user)
    else
      {:error, %Ecto.Changeset{} = changeset} ->
        Logger.debug("failed Google insert #{inspect(changeset.errors)}")

        conn
        |> put_flash(
          :error,
          "We were unable to fetch the necessary information from your Google account"
        )
        |> redirect(to: "/")

      {:error, reason} ->
        Logger.debug("failed Google exchange #{inspect(reason)}")

        conn
        |> put_flash(:error, "We were unable to contact Google. Please try again later")
        |> redirect(to: "/")
    end
  end

  def handle_oauth(conn, p) do
    p |> dbg()
    halt(conn)
  end
end
