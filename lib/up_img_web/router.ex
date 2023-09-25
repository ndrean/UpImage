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

  pipeline :google do
    plug CheckCsrf
    plug :accepts, ["json"]
  end

  pipeline :redirect_if_user do
    plug FetchUser
  end

  scope "/", UpImgWeb do
    pipe_through [:browser]

    get "/github/callback", GithubCallbackController, :new
  end

  scope "/", UpImgWeb do
    pipe_through [:google]

    post "/google/callback", GoogleCallbackController, :handle
  end

  scope "/", UpImgWeb do
    pipe_through [:browser, :redirect_if_user]
    get "/", RedirectController, :redirect_authenticated

    delete "/signout", LogOutController, :sign_out

    live_session :default, on_mount: [{UpImgWeb.UserAuth, :current_user}] do
      live "/signin", SignInLive
      live "/welcome", WelcomeLive
    end

    live_session :authenticated,
      on_mount: [{UpImgWeb.UserAuth, :ensure_authenticated}] do
      live "/liveview_clientless", NoClientLive
    end
  end

  # Other scopes may use custom stacks.
  # scope "/api", UpImgWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:up_img, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: UpImgWeb.Telemetry
      # forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
