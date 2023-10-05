defmodule UpImgWeb.Router do
  use UpImgWeb, :router
  # alias UpImgWeb.RedirectController
  alias GoogleCallbackController
  alias UpImg.Plug.CheckCsrf
  alias UpImgWeb.Plug.FetchUser

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {UpImgWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  scope "/", UpImgWeb do
    pipe_through [:browser]

    get "/signout", LogOutController, :sign_out
    get "/github/callback", GithubCallbackController, :new
    get "/sitemap", SitemapController, :index
  end

  # Google sends urlencoded and no more json
  pipeline :google do
    plug Plug.Parsers,
      parsers: [:urlencoded],
      pass: ["text/html"]

    plug CheckCsrf
  end

  scope "/", UpImgWeb do
    pipe_through [:google]

    post "/google/callback", GoogleCallbackController, :handle
  end

  pipeline :redirect_if_user do
    plug FetchUser
  end

  scope "/", UpImgWeb do
    pipe_through [:browser, :redirect_if_user]
    get "/", RedirectController, :redirect_authenticated
    # get "/signout", LogOutController, :sign_out

    # delete "/signout", LogOutController, :sign_out

    live_session :default, on_mount: [{UpImgWeb.UserAuth, :current_user}] do
      live "/signin", SignInLive
      live "/welcome", WelcomeLive
    end

    live_session :authenticated,
      on_mount: [{UpImgWeb.UserAuth, :ensure_authenticated}] do
      live "/liveview_clientless", NoClientLive
      live "/api_liveview", ApiLive
      # live "/:profile_username", ProfileLive
    end
  end

  # Mulitpart for multiple files parsing.
  pipeline :api_multi do
    plug :accepts, ["json"]

    plug CORSPlug,
      origin: ["*"]

    plug Plug.Parsers,
      parsers: [:fd_multipart, :json],
      pass: ["image/jpg", "image/png", "image/webp", "iamge/jpeg"],
      json_decoder: Jason,
      multipart_to_params: {Plug.Parsers.FD_MULTIPART, :multipart_to_params, []},
      body_reader: {Plug.Parsers.FD_MULTIPART, :read_body, []}
  end

  scope "/api", UpImgWeb do
    pipe_through :api_multi
    get "/", ApiController, :create
    post "/", ApiController, :handle
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  # if Application.compile_env(:up_img, :dev_routes) do
  # If you want to use the LiveDashboard in production, you should put
  # it behind authentication and allow only admins to access it.
  # If your application does not have an admins-only section yet,
  # you can use Plug.BasicAuth to set up some basic authentication
  # as long as you are also using SSL (which you should anyway).
  # import Phoenix.LiveDashboard.Router

  # scope "/dev" do
  # pipe_through :browser

  # live_dashboard "/dashboard", metrics: UpImgWeb.Telemetry
  # forward "/mailbox", Plug.Swoosh.MailboxPreview
  # end
  # end
end
