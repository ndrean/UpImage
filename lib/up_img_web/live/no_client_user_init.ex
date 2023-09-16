defmodule UpImgWeb.NoClientUserInit do
  import Phoenix.LiveView
  import Phoenix.Component

  alias UpImg.Accounts
  require Logger

  @upload_dir Application.app_dir(:up_img, ["priv", "static", "image_uploads"])

  @moduledoc """
  Following <https://hexdocs.pm/phoenix_live_view/security-model.html#mounting-considerations>
  """

  # defp path_in_socket(_p, url, socket) do
  #   {:cont, Phoenix.Component.assign(socket, :current_path, URI.parse(url).path)}
  # end

  @spec on_mount(:default, any, any, Phoenix.LiveView.Socket.t()) ::
          {:cont, map} | {:halt, Phoenix.LiveView.Socket.t()}
  def on_mount(:default, _p, %{"user_id" => user_id}, socket) do
    File.mkdir_p(@upload_dir)

    # peer_data = get_connect_info(socket, :peer_data) )
    # ua = get_connect_info(socket, :user_agent)

    socket =
      assign_new(socket, :current_user, fn ->
        Accounts.get_user!(user_id)
      end)

    case socket.assigns.current_user do
      nil ->
        Logger.warning("No user found ")

        {:halt, redirect(socket, to: "/")}

      _ ->
        Logger.info("On mount check_________")
        {:cont, socket}
    end
  end

  def on_mount(:default, _p, _session, socket) do
    Logger.warning("No user")
    {:halt, redirect(socket, to: "/")}
  end
end
