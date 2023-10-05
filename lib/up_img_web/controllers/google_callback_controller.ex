defmodule UpImgWeb.GoogleCallbackController do
  use UpImgWeb, :controller
  alias UpImg.Accounts
  require Logger

  def handle(conn, params) do
    params |> dbg()
    with {:ok, profil} <-
           ElixirGoogleCerts.verified_identity(%{jwt: params.credential}),
         {:ok, user} <- Accounts.register_google_user(profil) do
      conn
      |> Plug.Conn.fetch_session()
      |> Phoenix.Controller.fetch_flash()
      |> Phoenix.Controller.put_flash(:info, "Welcome #{user.email}")
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
        |> put_flash(:error, "Please try again later")
        |> redirect(to: "/")
    end
  end
end
