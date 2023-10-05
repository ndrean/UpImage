defmodule UpImgWeb.SitemapHTML do
  use UpImgWeb, :html
  embed_templates "sitemap_html/*"

  defmacro today do
    quote do
      Date.utc_today()
    end
  end

  def pages do
    [
      ~p"/",
      ~p"/welcome",
      ~p"/liveview_clientless",
      ~p"/api"
      # ~p"/api_liveview"
    ]
  end

  def show_pages do
    for p <- pages() do
      route = UpImgWeb.Endpoint.url() <> p

      """
      <url>
        <loc>#{route}</loc>
        <lastmod>#{today()}</lastmod>
        <changefreq>weekly</changefreq>
      </url>
      """
    end
  end
end
