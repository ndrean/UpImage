defmodule UpImgWeb.GithubCallbackController do
  use UpImgWeb, :controller
  require Logger

  alias UpImg.Accounts

  def new(conn, %{"code" => code, "state" => state}) do
    client = github_client(conn)

    with {:ok, info} <- client.exchange_access_token(code: code, state: state),
         %{info: info, primary_email: primary, token: token} = info,
         {:ok, user} <- Accounts.register_github_user(primary, info, token) do
      conn
      |> put_flash(:info, "Welcome #{user.email}")
      |> UpImgWeb.UserAuth.log_in_user(user)
    else
      {:error, %Ecto.Changeset{} = changeset} ->
        Logger.debug("failed GitHub insert #{inspect(changeset.errors)}")

        conn
        |> put_flash(
          :error,
          "We were unable to fetch the necessary information from your GithHub account"
        )
        |> redirect(to: "/")

      {:error, reason} ->
        Logger.debug("failed GitHub exchange #{inspect(reason)}")

        conn
        |> put_flash(:error, "We were unable to contact GitHub. Please try again later")
        |> redirect(to: "/")
    end
  end

  def new(conn, %{"provider" => "github", "error" => "access_denied"}) do
    redirect(conn, to: "/")
  end

  defp github_client(conn) do
    conn.assigns[:github_client] ||
      UpImg.Github
      |> dbg()
  end
end
