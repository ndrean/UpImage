defmodule UpImgWeb.UserAuth do
  @moduledoc """
  Assigns a current_user to the socket
  """
  use UpImgWeb, :verified_routes
  import Plug.Conn
  import Phoenix.Controller

  alias Phoenix.LiveView
  alias UpImg.Accounts

  # assigns a "current_user" to the socket
  def on_mount(:current_user, _params, session, socket) do
    case session do
      %{"user_id" => user_id} ->
        {:cont,
         Phoenix.Component.assign_new(socket, :current_user, fn -> Accounts.get_user(user_id) end)}

      %{} ->
        {:cont, Phoenix.Component.assign(socket, :current_user, nil)}
    end
  end

  # redirects if no current_user
  def on_mount(:ensure_authenticated, _params, session, socket) do
    case session do
      %{"user_id" => user_id} ->
        new_socket =
          Phoenix.Component.assign_new(socket, :current_user, fn ->
            Accounts.get_user!(user_id)
          end)

        %Accounts.User{} = new_socket.assigns.current_user
        {:cont, new_socket}

      %{} ->
        {:halt, redirect_require_login(socket)}
    end
  rescue
    Ecto.NoResultsError -> {:halt, redirect_require_login(socket)}
  end

  defp redirect_require_login(socket) do
    socket
    |> LiveView.put_flash(:error, "Please sign in")
    |> LiveView.redirect(to: ~p"/signin")
  end

  @doc """
  Logs the user in.

  It renews the session ID and clears the whole session to avoid fixation attacks. See the renew_session function to customize this behaviour.

  It also sets a `:live_socket_id` key in the session, so LiveView sessions are identified and automatically
  disconnected on log out. The line can be safely removed if you are not using LiveView.
  """
  def log_in_user(conn, user) do
    require Logger

    conn
    |> renew_session()
    |> put_session(:user_id, user.id)
    |> put_session(:live_socket_id, "users_sessions:#{user.id}")
    |> assign(:current_user, user)
    |> redirect(to: ~p"/")
  end

  defp renew_session(conn) do
    conn
    |> configure_session(renew: true)
    |> clear_session()
  end

  @doc """
  Logs the user out.

  It clears all session data for safety. See renew_session.
  """
  def log_out_user(conn) do
    conn
    |> renew_session()
    |> redirect(to: ~p"/")
  end
end
