defmodule UpImgWeb.NoClientPreloading do
  use Phoenix.Component
  import UpImgWeb.CoreComponents
  alias Phoenix.LiveView.JS

  def display(assigns) do
    ~H"""
    <div class="flex flex-col flex-1 mt-10 md:mt-0 md:ml-4">
      <div>
        <h2 class="text-base font-semibold leading-7 text-gray-900">Uploaded files locally</h2>
        <p class="mt-1 text-sm leading-6 text-gray-600">
          The images below are temporarilly saved on the server. You can <b>upload</b>
          them to S3 or <b>prune</b> them.
        </p>

        <p class={"
            #{if length(@uploaded_files_locally) == 0 do "block" else "hidden" end}
            text-xs leading-7 text-gray-400 text-center my-10"}>
          No files uploaded.
        </p>
        <ul id="uploaded_files_locally" role="list" class="divide-y divide-gray-100">
          <li
            :for={file <- @uploaded_files_locally}
            class="uploaded-local-item relative flex justify-between gap-x-6 py-5"
            id={"preloded-"<>file.uuid}
          >
            <div class="flex gap-x-4">
              <div class="min-w-0 flex-auto">
                <p>
                  <.link
                    class="text-sm leading-6 break-all underline text-indigo-600"
                    href={file.resized_url}
                    target="_blank"
                    rel="noopener noreferrer"
                  >
                    <img
                      class="block max-w-fit max-h-48 w-auto h-auto flex-none bg-gray-50"
                      src={file.thumb_url}
                      alt="thumbnail"
                    />
                  </.link>
                </p>
              </div>
            </div>
            <div class="flex flex-col items-center justify-center space-y-4">
              <button phx-click="remove-selected" phx-value-uuid={file.uuid} class="submit_button rounded-md px-3 py-2 text-sm font-semibold text-white shadow-sm bg-red-500 hover:bg-red-700">
                <.icon name="hero-trash" />
              </button>
              <button
                id={"#submit_button-#{file.uuid}"}
                phx-click={
                  JS.push("upload_to_s3",
                    value: %{uuid: file.uuid}
                  )
                }
                class="submit_button rounded-md bg-indigo-600 px-3 py-2 text-sm font-semibold text-white shadow-sm hover:bg-lime-600 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-600"
              >
                <.icon name="hero-cloud-arrow-up" />
              </button>
            </div>
          </li>
        </ul>
      </div>
    </div>
    """
  end

  def error_to_string(:too_large), do: "File is too large."
  def error_to_string(:not_accepted), do: "You have selected an unacceptable file type."
  def error_to_string(:too_many_files), do: "You uploaded too many files"
  # coveralls-ignore-start
  def error_to_string(:external_client_failure),
    do: "Couldn't upload files to S3. Open an issue on Github and contact the repo owner."
end
