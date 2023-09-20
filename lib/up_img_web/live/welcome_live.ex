defmodule UpImgWeb.WelcomeLive do
  use UpImgWeb, :live_view

  def render(assigns) do
    ~H"""
    <div>
      <div class="mx-auto max-w-2xl py-6 sm:py-6 lg:py-6">
        <div class="text-center">
          <img src={~p"/images/camera.svg"} width={200} class="mx-auto h-24 w-auto" alt="workflow" />
          <h1 class="text-4xl mt-4 font-bold tracking-tight text-gray-900 sm:text-6xl">
            Simple file uploader to WEBP
          </h1>

          <%= if @current_user do %>
            <div class="space-y-6 mb-4 mt-6">
              <.link
                navigate={~p"/liveview_clientless"}
                class="rounded-md bg-purple-600 px-3.5 py-2.5 text-sm font-semibold text-white shadow-sm hover:bg-purple-500 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-purple-600"
              >
                Go to files upload <.icon name="hero-cloud-arrow-up" />
              </.link>
            </div>
          <% else %>
            <div class="mt-10 flex items-center justify-center gap-x-6">
              <.link
                href={~p"/signin"}
                class="rounded-md bg-purple-600 px-3.5 py-2.5 text-sm font-semibold text-white shadow-sm hover:bg-purple-500 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-purple-600"
              >
                Quick sign-in <.icon name="hero-arrow-right-on-rectangle" />
              </.link>
            </div>
          <% end %>
          <p :if={!@current_user} class="text-xs pt-4">
            You are asked to register an account to upload pictures. You can use <b>only one email</b> per provider.
            We don't use your data and only keep the minimum needed to retrieve your files from the service (your name and email).
            Furthermore, your email is encrypted.
          </p>
          <p class="mt-10 text-lg leading-8 text-gray-600">
          You can upload pictures. These pictures will be transformed into WEBP format. You are limited to sizes no more than <b>5Mb</b>.

          </p>
        </div>
      </div>
    </div>
    """
  end
end
