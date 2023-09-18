defmodule UpImgWeb.ProfileLive do
  use UpImgWeb, :live_view

  def render(assigns) do
    assigns.current_user.name |> dbg()

    ~H"""
    <div>
      <h1>Welcome <%= @current_user.name %></h1>
      <div class="mx-auto max-w-2xl py-32 sm:py-48 lg:py-56">
        <div class="text-center">
          <h1 class="text-4xl font-bold tracking-tight text-gray-900 sm:text-6xl">
            Simple file upload
          </h1>

          <div class="mt-10 flex items-center justify-center gap-x-6">
            <.link
              navigate={~p"/liveview_clientless"}
              class="rounded-md bg-purple-600 px-3.5 py-2.5 text-sm font-semibold text-white shadow-sm hover:bg-purple-500 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-purple-600"
            >
            Go to files upload <.icon name="hero-cloud-arrow-up" />
            </.link>
          </div>
          <p class="text-xs pt-4" :if={!@current_user}>You are asked to register an account to upload pictures.
        We don't use your data and only keep the minimum needed to retrieve your files from the service (your name and email).
        Furthermore, your email is encrypted.
        </p>
          <p class="mt-10 text-lg leading-8 text-gray-600">
            You can upload up to 10 files. The file can only be an <b>image</b>
            and no more than <b>2Mb</b>.
          </p>
        </div>
      </div>
    </div>
    """
  end
end
