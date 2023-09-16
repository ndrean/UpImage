defmodule UpImgWeb.Layouts do
  use UpImgWeb, :html

  def github_img(assigns) do
    ~H"""
    <img src={@gh} alt="github logo" class="max-w-[24px]" />
    """
  end

  embed_templates "layouts/*"
end
