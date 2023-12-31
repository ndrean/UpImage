defmodule UpImgWeb.SignInLive do
  use UpImgWeb, :live_view
  require Logger

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-50 flex flex-col justify-center py-12 sm:px-6 lg:px-8">
      <div>
        <img src={~p"/images/camera.svg"} width={200} class="mx-auto h-24 w-auto" alt="workflow" />

        <h2 class="mt-6 text-center text-3xl font-extrabold text-gray-900">
          Create or Sign in to your account
        </h2>
        <p class="text-xs pt-4">
          You are asked to register an account. Your email is safely encrypted.
          We don't use your data and only keep the minimum needed to retrieve your files from the service (your name and email).
        </p>
      </div>

      <div class="mt-8 sm:mx-auto sm:w-full sm:max-w-md">
        <div class="bg-white py-8 px-4 shadow sm:rounded-lg sm:px-10">
          <div class="space-y-6 mb-4">
            <a
              href={UpImg.Github.authorize_url()}
              class="w-full flex items-center justify-around py-2 border border-transparent rounded-md shadow-sm text-sm font-bold bg-indigo-200 hover:bg-indigo-400 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
            >
              <img src={~p"/images/github-mark.svg"} width={24} /> Sign in with Github
            </a>
          </div>
          <div>
            <script src="https://accounts.google.com/gsi/client" async defer>
            </script>
            <div class="border-solid">
              <div
                phx-update="ignore"
                id="g_id_onload"
                data-client_id={UpImg.EnvReader.google_id()}
                data-auto_prompt="true"
                data-context="signin"
                data-ux_mode="popup"
                data-login_uri={UpImg.google_callback()}
                data-itp_support="true"
              >
              </div>

              <div
                id="g-button"
                phx-update="ignore"
                class="g_id_signin"
                data-type="standard"
                data-shape="pill"
                data-theme="filled_blue"
                data-text="signin_with"
                data-size="large"
                data-logo_alignment="left"
              >
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
