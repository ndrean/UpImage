defmodule UpImgWeb.GithubCallbackController do
  use UpImgWeb, :controller
  require Logger

  alias UpImg.Accounts
  alias UpImg.Github
  alias UpImgWeb.UserAuth

  def new(conn, %{"code" => code, "state" => state}) do
    with {:ok, info} <- Github.exchange_access_token(code: code, state: state),
         {:ok, user} <- Accounts.register_github_user(info) do
      conn
      |> put_flash(:info, "Welcome #{user.email}")
      |> UserAuth.log_in_user(user)
    else
      {:error, %Ecto.Changeset{} = changeset} ->
        Logger.warning("failed GitHub insert #{inspect(changeset.errors)}")

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
end
