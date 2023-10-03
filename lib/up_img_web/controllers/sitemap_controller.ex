defmodule UpImgWeb.SitemapController do
  use UpImgWeb, :controller

  def index(conn, _) do
    xml = UpImgWeb.SitemapHTML.index(%{})

    conn
    |> put_resp_content_type("text/xml")
    |> text(xml)
  end
end
