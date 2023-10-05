defmodule UpImgWeb.ApiLive do
  use UpImgWeb, :live_view

  def render(assigns) do
    ~H"""
    <div></div>
    """
  end

  def mount(_, _, socket) do
    {:ok, socket}
  end
end
