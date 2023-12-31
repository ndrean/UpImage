defmodule UpImgWeb.UploadForm do
  @moduledoc """
  HTML markup for the form to accept files.
  """
  use Phoenix.Component

  def render(assigns) do
    ~H"""
    <div class="flex flex-col flex-1 md:mr-4">
      <!-- Drag and drop -->
      <div class="space-y-12">
        <div class="border-gray-900/10 pb-12">
          <h2 class="text-base font-semibold leading-7 text-gray-900">
            Image Upload
          </h2>
          <p class="mt-1 text-sm leading-6 text-gray-600">
            Drag your images and preview them before uploading to the cloud! ☁️
          </p>
          <p class="mt-1 text-sm leading-6 text-gray-600">
            You may add up to <%= @uploads.image_list.max_entries %> exhibits at a time and get_limited to a
            size of <%= div(@uploads.image_list.max_file_size, 1_000) %> kB
          </p>
          <form
            class="mt-10 grid grid-cols-1 gap-x-6 gap-y-8"
            phx-change="validate"
            phx-submit="save"
            id="upload-form"
          >
            <div class="col-span-full">
              <div
                class="mt-2 flex justify-center rounded-lg border border-dashed border-gray-900/25 px-6 py-10"
                phx-drop-target={@uploads.image_list.ref}
              >
                <div class="text-center">
                  <svg
                    class="mx-auto h-12 w-12 text-gray-300"
                    viewBox="0 0 24 24"
                    fill="currentColor"
                    aria-hidden="true"
                  >
                    <path
                      fill-rule="evenodd"
                      d="M1.5 6a2.25 2.25 0 012.25-2.25h16.5A2.25 2.25 0 0122.5 6v12a2.25 2.25 0 01-2.25 2.25H3.75A2.25 2.25 0 011.5 18V6zM3 16.06V18c0 .414.336.75.75.75h16.5A.75.75 0 0021 18v-1.94l-2.69-2.689a1.5 1.5 0 00-2.12 0l-.88.879.97.97a.75.75 0 11-1.06 1.06l-5.16-5.159a1.5 1.5 0 00-2.12 0L3 16.061zm10.125-7.81a1.125 1.125 0 112.25 0 1.125 1.125 0 01-2.25 0z"
                      clip-rule="evenodd"
                    />
                  </svg>
                  <div class="mt-4 flex text-sm leading-6 text-gray-600">
                    <label
                      for="file-upload"
                      class="relative cursor-pointer rounded-md bg-white font-semibold text-indigo-600 focus-within:outline-none focus-within:ring-2 focus-within:ring-indigo-600 focus-within:ring-offset-2 hover:text-indigo-500"
                    >
                      <div>
                        <label class="cursor-pointer">
                          <.live_file_input upload={@uploads.image_list} class="hidden" /> Upload
                        </label>
                      </div>
                    </label>
                    <p class="pl-1">or drag and drop</p>
                  </div>
                  <p class="text-xs leading-5 text-gray-600">PNG, JPG, WEBP up to 5MB</p>
                </div>
                <% are_files_uploadable?(@uploads.image_list) %>
              </div>
            </div>
          </form>
        </div>
      </div>
    </div>
    """
  end

  def are_files_uploadable?(image_list) do
    error_list = Map.get(image_list, :errors)

    case Enum.empty?(error_list) do
      true ->
        true

      false ->
        send(self(), {:upload_error, error_list})
        false
    end
  end
end
