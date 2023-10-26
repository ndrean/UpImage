defmodule UpImgWeb.WelcomeLive do
  use UpImgWeb, :live_view

  def render(assigns) do
    ~H"""
    <div>
      <div class="mx-auto max-w-2xl py-6 sm:py-6 lg:py-6">
        <div class="text-center">
          <img src={~p"/images/camera.svg"} width={200} class="mx-auto h-24 w-auto" alt="workflow" />
          <h1 class="text-4xl mt-4 font-bold tracking-tight text-gray-900 sm:text-6xl">
            Simple file uploader to rescale into WEBP format
          </h1>

          <%= if @current_user do %>
            <%!-- <div class="space-y-6 mb-4 mt-6">
              <.link
                id="to-uploader"
                navigate={~p"/liveview_clientless"}
                class="rounded-md bg-purple-600 px-3.5 py-2.5 text-sm font-semibold text-white shadow-sm hover:bg-purple-500 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-purple-600"
              >
                Go to files upload <.icon name="hero-cloud-arrow-up" />
              </.link>
            </div>--%>
            <div class="space-y-6 mb-4 mt-6">
              <.link
                id="direct-uploader"
                navigate={~p"/direct"}
                class="rounded-md bg-purple-600 px-3.5 py-2.5 text-sm font-semibold text-white shadow-sm hover:bg-purple-500 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-purple-600"
              >
                Upload pictures<.icon name="hero-cloud-arrow-up" />
              </.link>
            </div>
          <% else %>
            <div class="mt-10 flex items-center justify-center gap-x-6">
              <.link
                href={~p"/signin"}
                id="signin-link"
                class="rounded-md bg-purple-600 px-3.5 py-2.5 text-sm font-semibold text-white shadow-sm hover:bg-purple-500 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-purple-600"
              >
                Quick sign-in <.icon name="hero-arrow-right-on-rectangle" />
              </.link>
            </div>
          <% end %>
          <p :if={!@current_user} class="text-xs pt-4">
            You are asked to register an account to upload pictures.  No password is required. Your email is safely encrypted.
            We only use your data to retrieve your files from the service.
          </p>
          <p class="mt-10 text-lg text-left leading-8 text-gray-600">
            You can upload pictures. These pictures will be rescaled and transformed into WEBP format. You are limited to sizes no more than <b>5Mb</b>.
          </p>
          <hr />

          <h2 class="mb-4 mt-4">
            <.link
              href="#"
              class="rounded-md bg-purple-600 mb-2 px-3.5 py-2.5 text-sm font-semibold text-white shadow-sm hover:bg-purple-500 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-purple-600"
            >
              Go to the API (not finished)
            </.link>
          </h2>
          <details>
            <summary>
              Click for details.
            </summary>
            <p class="text-left">
              The API offers two endopints at "https://up-image.fly.dev/api".
              It offers a GET for passing an URL, and a POST for submitting files via a FormData.
              By default, any uploaded image will be resized to a maximum width of 1440px.
            </p>
            <p class="text-left">
              You have a GET where you pass a query string with the "url" key and possibly the desired width "w" for the desired resizing.
              You can try:
            </p>
            <code class="text-left">
              curl -X GET https://up-image.fly.dev/api?url=https://world-celebs.com/public/media/resize/800x-/2019/8/5/porter-robinson-3.jpg&h=600&w=600
            </code>
            <p>
              You also have a POST endpoint where you can submit your FormData with multiple files from the client.
              You can possibly the key "w" for the desired width resizing. Note that it is not set individually.
            </p>
          </details>
        </div>
      </div>
      <footer>
        <p class="bg-brand/5 text-brand rounded-full px-2 font-bold leading-6 text-center text-xs">
          Elixir: <%= System.build_info().build %>,
          Phoenix: <%= Application.spec(:phoenix, :vsn) %>, LV: <%= Application.spec(
            :phoenix_live_view,
            :vsn
          ) %>, Vix: <%= Vix.Vips.version() %>
        </p>
      </footer>
    </div>
    """
  end
end
