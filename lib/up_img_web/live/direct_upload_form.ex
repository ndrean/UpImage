defmodule UpImgWeb.DirectUploadForm do
  use Phoenix.Component

  def display(assigns) do
    ~H"""
    <div>
      <form
        class="mt-10 grid grid-cols-1 gap-x-6 gap-y-8 border-solid border-2"
        phx-change="validate"
        phx-submit="save"
        id="direct-upload-form"
      >
        <%!-- <div phx-drop-target={@uploads.direct_images.ref}> --%>
        <div>
          <.live_file_input upload={@uploads.images} hidden />

          <label for="f-input">
            Choose a picture (JPEG, PNG, WEBP)
            <input
              type="file"
              data-el-input
              multiple
              accept=".jpeg, .jpg, .png, .webp"
              name="images"
              id="f-input"
              phx-hook="HandleImages"
            />
          </label>
        </div>
        <button type="submit">Upload</button>
      </form>

      <%= for entry <- @uploads.images.entries do %>
        <figure :if={String.contains?(entry.client_name, "m200.webp")}>
          <.live_img_preview entry={entry} id={entry.uuid} />
          <figcaption><%= entry.client_name %></figcaption>
        </figure>
      <% end %>
    </div>
    """
  end
end
