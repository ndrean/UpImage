defmodule UpImgWeb.NoClientLive do
  use UpImgWeb, :live_view
  alias UpImg.Gallery
  alias UpImg.Gallery.Url
  alias UpImg.Repo

  alias Vix.Vips.Image
  alias Vix.Vips.Operation

  require Logger

  @thumb_size 200
  # @cleaning_timer 60 * 1_000

  @upload_dir Application.app_dir(:up_img, ["priv", "static", "image_uploads"])

  @delete_bucket_and_db "Sucessfully deleted from bucket and database"
  @error_delete_object_in_bucket "Failed to delete from bucket"
  @error_saving_in_bucket "Could not save in the bucket"
  @error_in_db_but_deleted_from_bucket "Object deleted in bucket but not found in database"
  @timeout_bucket "Upload to bucket, timeout"

  @impl true
  def mount(_, _, socket) do
    File.mkdir_p!(@upload_dir)

    cleaner_pid = nil
    # case Gallery.Clean.start(user_id: socket.assigns.current_user.id, timer: @cleaning_timer) do
    #   {:ok, pid} ->
    #     pid

    #   {:error, {:already_started, pid}} ->
    #     pid
    # end

    init_assigns = %{
      limit: 4,
      page: 0,
      offset: 3,
      uploaded_files_locally: [],
      errors: [],
      cleaner_pid: cleaner_pid
    }

    socket =
      socket
      |> assign(init_assigns)
      |> allow_upload(:image_list,
        accept: ~w(.jpg .jpeg .png .webp),
        max_entries: 20,
        chunk_size: 64_000,
        auto_upload: true,
        max_file_size: 2_000_000,
        progress: &handle_progress/3
      )
      |> stream_configure(:uploaded_files_to_S3, dom_id: &"uploaded-s3-#{&1.uuid}")
      |> paginate(0)
      |> push_event("screen", %{})

    {:ok, socket}

    # Do not define presign_upload. This will create a local photo in /vars
  end

  def paginate(socket, page) do
    %{limit: limit, offset: offset, current_user: current_user} = socket.assigns
    files = Gallery.get_limited_urls_by_user(current_user, limit, page * offset)
    stream(socket, :uploaded_files_to_S3, files, at: -1)
  end

  # With `auto_upload: true`, we can consume files here
  # loop while receiving chunks
  def handle_progress(:image_list, entry, socket) when entry.done? == false do
    {:noreply, socket}
  end

  def handle_progress(:image_list, entry, socket) when entry.done? do
    uploaded_file =
      consume_uploaded_entry(socket, entry, fn %{path: path} ->
        # %{uuid: uuid, client_name: client_name, client_type: client_type} = entry

        client_name = clean_name(entry.client_name)

        check_if_exists =
          Enum.find(socket.assigns.uploaded_files_locally, &(&1.client_name == client_name))

        case check_if_exists do
          nil ->
            entry =
              entry
              |> Map.put(:client_name, client_name)
              |> Map.put(:image_path, build_path(client_name))
              |> Map.put(:image_url, set_image_url(client_name))
              |> Map.merge(%{thumb_url: nil, thumb_path: nil, errors: []})

            # Copying the file from temporary system folder to static folder
            :ok =
              File.stream!(path, [], 64_000)
              |> Stream.into(File.stream!(entry.image_path))
              |> Stream.run()

            {:ok, entry}

          _ ->
            {:ok, :not_unique}
        end
      end)

    case uploaded_file do
      :not_unique ->
        {:noreply, socket}

      entry ->
        pid = self()

        Task.Supervisor.start_child(UpImg.TaskSup, fn ->
          transform_image(pid, entry, socket.assigns.screen)
        end)

        {:noreply, update(socket, :uploaded_files_locally, &(&1 ++ [uploaded_file]))}
    end
  end

  @doc """
  Transforms (thumbnail & resize to max screen) into WEBP and saves on server in "/image_uploads"

  The data `%{"screenHeight" => h, "screenWidth" => w} = screen` is handled by a JS hook in the `mount` with a `push_event`.
  """
  def transform_image(pid, entry, screen) do
    %{client_name: client_name, image_path: image_path} = entry

    # image_path
    # "/Users/.../image_uploads/Screenshot2023-08-04at210431.png"

    thumb_name = thumb_name(client_name)
    thumb_path = thumb_name(client_name) |> build_path()
    # "/Users/.../image_uploads/Screenshot2023-08-04at210431-th.webp"

    rename_to_webp =
      if Path.extname(client_name) == ".webp",
        do: client_name,
        else: (client_name |> Path.rootname()) <> ".webp"

    # "Screenshot2023-08-04at210431.webp"

    resized_name = "resized-" <> rename_to_webp
    resized_path = build_path(resized_name)
    # "/Users/.../image_uploads/resized-Screenshot2023-08-04at210431.webp"

    entry =
      entry
      |> Map.merge(%{
        resized_path: resized_path,
        resized_name: resized_name,
        thumb_name: thumb_name,
        thumb_path: thumb_path
      })

    with {:ok, img_origin} <- Image.new_from_file(image_path),
         {:ok, scale} <- get_scale(img_origin, screen),
         {:ok, img_resized} <- Operation.resize(img_origin, scale),
         :ok <- Operation.webpsave(img_resized, resized_path),
         {:ok, img_thumb} <- Operation.thumbnail(image_path, @thumb_size),
         :ok <- Operation.webpsave(img_thumb, thumb_path) do
      send(pid, {:transform_success, entry})
    else
      {:error, msg} ->
        send(pid, {:transform_error, msg})
    end
  end

  @doc """
  Applies a resizing based on the current screen size.
  """
  def get_scale(img, screen) do
    %{"screenHeight" => h, "screenWidth" => w} = screen
    h_origin = Image.height(img)
    w_origin = Image.width(img)
    hscale = if h < h_origin, do: h / h_origin, else: 1
    wscale = if w < w_origin, do: w / w_origin, else: 1
    {:ok, min(hscale, wscale)}
  rescue
    _ ->
      {:error, "Can't read image"}
  end

  # callback from transformation operation.
  @impl true
  def handle_info({:transform_error, msg}, socket) do
    {:noreply, put_flash(socket, :error, inspect(msg))}
  end

  # callback to update the socket once the transformation is done
  @impl true
  def handle_info({:transform_success, entry}, socket) do
    local_images = socket.assigns.uploaded_files_locally

    img = find_image(local_images, entry.uuid)

    img =
      Map.merge(img, %{
        resized_path: entry.resized_path,
        resized_url: set_image_url(entry.resized_name),
        thumb_url: set_image_url(entry.thumb_name),
        thumb_path: entry.thumb_path,
        image_path: entry.image_path
      })

    {:noreply,
     socket
     |> update(
       :uploaded_files_locally,
       &find_and_replace(&1, entry.uuid, img)
     )}
  end

  # success callback from upload to S3.
  # update the stream and the db
  @impl true
  def handle_info({:bucket_success, map}, socket) do
    current_user = socket.assigns.current_user

    data =
      Map.new()
      |> Map.put(:resized_url, map.resized_url)
      |> Map.put(:thumb_url, map.thumb_url)
      |> Map.put(:uuid, map.uuid)
      |> Map.put(:user_id, current_user.id)

    # streams does not accept a map but accepts an UploadEntry struct

    case Url.changeset(%Url{}, data) |> Repo.insert() do
      {:ok, _} ->
        new_file =
          %Phoenix.LiveView.UploadEntry{}
          |> Map.merge(data)

        {:noreply, stream_insert(socket, :uploaded_files_to_S3, new_file)}

      {:error, changeset} ->
        {:noreply, put_flash(socket, :error, Url.traverse(changeset))}
    end
  end

  # error callback from upload to S3
  @impl true
  def handle_info({:upload_error}, socket) do
    {:noreply, put_flash(socket, :error, @error_saving_in_bucket)}
  end

  # callback from deletion failure from bucket
  @impl true
  def handle_info({:failed_deletion_from_bucket}, socket) do
    Logger.warning("failed_deletion_from_bucket")
    {:noreply, put_flash(socket, :error, @error_delete_object_in_bucket)}
  end

  # callback from successfull object deletion from bucket
  @impl true
  def handle_info({:success_deletion_from_bucket, dom_id, uuid}, socket) do
    Repo.transaction(fn repo ->
      data = repo.get_by(Url, %{uuid: uuid})

      case data do
        nil ->
          {:error, :not_found_in_database}

        data ->
          repo.delete(data)
      end
    end)
    |> case do
      {:ok, {:ok, _}} ->
        {:noreply,
         socket
         |> put_flash(:info, @delete_bucket_and_db)
         |> stream_delete_by_dom_id(:uploaded_files_to_S3, dom_id)}

      {:ok, {:error, msg}} ->
        Logger.warning("transaction delete failed " <> inspect(msg))

        {:noreply,
         socket
         |> put_flash(:error, @error_in_db_but_deleted_from_bucket)}
    end
  end

  # error callback to "remove_safely" of local files
  @impl true
  def handle_info({:rm_error, msg}, socket) do
    {:noreply, put_flash(socket, :error, msg)}
  end

  @impl true
  def handle_info({:upload_error, error_list}, socket) do
    errors =
      error_list |> Enum.reduce([], fn {_ref, msg}, list -> [error_to_string(msg) | list] end)

    send(self(), {:cancel_upload})
    {:noreply, put_flash(socket, :error, inspect(errors))}
  end

  @impl true
  def handle_info({:cancel_upload}, socket) do
    # clean the uploads
    socket =
      socket.assigns.uploads.image_list.entries
      |> Enum.map(& &1.ref)
      |> Enum.reduce(socket, fn ref, socket -> cancel_upload(socket, :image_list, ref) end)

    {:noreply, assign(socket, :uploaded_files_locally, [])}
  end

  @impl true
  def handle_event("load-more", _, socket) do
    {:noreply,
     socket
     |> update(:page, &(&1 + 1))
     |> paginate(socket.assigns.page + 1)}
  end

  def handle_event("tabclosed", _unsigned_params, socket) do
    pid = self()

    Task.start(fn ->
      clean_local_uploaded_files(pid, socket.assigns.uploaded_files_locally)
    end)

    {:noreply, socket}
  end

  # remove temp files from server if user inactive.
  def handle_event("inactivity", _p, socket) do
    Logger.warning("inactive---------")

    pid = self()

    Task.start(fn ->
      clean_local_uploaded_files(pid, socket.assigns.uploaded_files_locally)
    end)

    {:noreply, push_redirect(socket, to: ~p"/")}
  end

  # callback to the JS hook `pushEvent` to capture page size
  # params are: %{"screenHeight" => h, "screenWidth" => w} = p
  @impl true
  def handle_event("page-size", p, socket), do: {:noreply, assign(socket, :screen, p)}

  @impl true
  def handle_event("validate", _params, socket), do: {:noreply, socket}

  # triggered by the "upload" front-end button: file per file
  @impl true
  def handle_event("upload_to_s3", %{"uuid" => uuid}, socket) do
    # Get file element from the local files array
    %{
      image_path: image_path,
      resized_path: resized_path,
      thumb_path: thumb_path,
      uuid: uuid
    } =
      find_image(socket.assigns.uploaded_files_locally, uuid)

    # Create 1) original file object and 2) thumbnail/compressed file object to upload
    file_resized =
      %{
        path: resized_path,
        content_type: "image/webp"
      }

    file_thumb =
      %{
        path: thumb_path,
        content_type: "image/webp"
      }

    # concurrently upload the 2 files to the bucket
    pid = self()
    Task.start(fn -> upload(pid, image_path, [file_resized, file_thumb], uuid) end)

    {:noreply,
     socket
     |> update(:uploaded_files_locally, fn list -> Enum.filter(list, &(&1.uuid != uuid)) end)}
  end

  # remove objects from bucket, triggered by front-end button
  @impl true
  def handle_event(
        "delete-uploaded",
        %{"key" => dom_id, "resized" => resized, "thumb" => thumb, "uuid" => uuid},
        socket
      ) do
    pid = self()
    bucket = UpImg.bucket()
    keys_to_delete = [Path.basename(resized), Path.basename(thumb)]

    keys_to_delete
    |> Task.async_stream(fn key ->
      ExAws.S3.delete_object(bucket, key)
      |> ExAws.request!()
    end)
    |> Stream.run()

    # verify that objects are removed
    Task.start(fn ->
      check_list =
        ExAws.S3.list_objects(bucket)
        |> ExAws.request!()
        |> Enum.filter(&Enum.member?(keys_to_delete, &1))

      case length(check_list) do
        0 ->
          send(pid, {:success_deletion_from_bucket, dom_id, uuid})

        _ ->
          send(pid, {:failed_deletion_from_bucket})
      end
    end)

    {:noreply, socket}
  end

  # rm files from server when unselected
  @impl true
  def handle_event("remove-selected", %{"uuid" => uuid}, socket) do
    %{
      thumb_path: thumb_path,
      client_name: client_name,
      resized_path: resized_path
    } =
      socket.assigns.uploaded_files_locally
      |> Enum.find(&(&1.uuid == uuid))

    handle_remove(self(), [thumb_path, resized_path, build_path(client_name)])

    {:noreply,
     socket
     |> update(:uploaded_files_locally, &Enum.filter(&1, fn img -> img.uuid != uuid end))}
  end

  def clean_local_uploaded_files(pid, files) do
    Enum.each(files, fn %{
                          thumb_path: thumb_path,
                          resized_path: resized_path,
                          client_name: client_name
                        } ->
      [thumb_path, resized_path, build_path(client_name)]
      |> Enum.each(&remove_safely(pid, &1))
    end)
  end

  # In Task.async_stream, use "on_timeout: :kill_task" to intercept the timeout error
  def upload(pid, image_path, files, uuid) do
    files
    |> Task.async_stream(&UpImg.Upload.upload/1, on_timeout: :kill_task)
    |> Enum.map(&handle_async_result/1)
    |> Enum.reduce([], fn res, acc ->
      case res do
        {:ok, {url, name}} ->
          [{url, name} | acc]

        {:error, msg} ->
          [{:error, msg} | acc]
      end
    end)
    |> handle_result(pid, uuid)

    # cleanup the files on the server
    [%{path: p1}, %{path: p2}] = files
    handle_remove(self(), [image_path, p1, p2])
  end

  def handle_remove(pid, list) do
    list
    |> Task.async_stream(&remove_safely(pid, &1))
    |> Stream.run()
  end

  def remove_safely(pid, file) do
    case File.rm(file) do
      :ok ->
        :ok

      {:error, msg} ->
        send(pid, {:rm_error, msg})
    end
  end

  def handle_result([{:error, _}, {:error, _}], pid, _uuid) do
    send(pid, {:upload_error})
  end

  # remove the thumbnail from the bucket
  def handle_result([{:error, msg}, url], pid, uuid) do
    handle_result([url, {:error, msg}], pid, uuid)
  end

  # remove the thumbnail from the bucket if not all completed
  def handle_result([{url, _name}, {:error, msg}], pid, _uuid) do
    Logger.warning("Upload error: " <> inspect(msg))

    Task.start(fn ->
      ExAws.S3.delete_object(UpImg.bucket(), Path.basename(url))
      |> ExAws.request!()
    end)

    send(pid, {:upload_error})
  end

  # success path of the upload action
  def handle_result([{url1, name1}, {url2, _name2}], pid, uuid) do
    case String.contains?(name1, "resized") do
      true ->
        send(
          pid,
          {:bucket_success, %{thumb_url: url2, resized_url: url1, uuid: uuid}}
        )

      false ->
        send(
          pid,
          {:bucket_success, %{thumb_url: url1, resized_url: url2, uuid: uuid}}
        )
    end
  end

  def handle_async_result({:ok, {:ok, %{url: url, name: name}}}), do: {:ok, {url, name}}
  def handle_async_result({:ok, {:error, :upload_fail}}), do: {:error, :bucket_error}
  def handle_async_result({:ok, {:error, :file_error}}), do: {:error, :file_error}
  def handle_async_result({:error, _msg}), do: {:error, :upload_error}
  def handle_async_result({:exit, :timeout}), do: {:error, @timeout_bucket}

  def find_and_replace(images, uuid, img) do
    Enum.map(images, fn image -> if image.uuid == uuid, do: img, else: image end)
  end

  def find_image(images, img_uuid) do
    Enum.find(images, fn %{uuid: uuid} ->
      uuid == img_uuid
    end)
  end

  def set_image_url(name) do
    Path.join([
      UpImgWeb.Endpoint.url(),
      UpImgWeb.Endpoint.static_path("/image_uploads"),
      name
    ])
  end

  def url_path(name) do
    UpImgWeb.Endpoint.static_path("/image_uploads/#{name}")
  end

  def clean_name(name) do
    rootname = name |> Path.rootname() |> String.replace(" ", "") |> String.replace(".", "")
    rootname <> Path.extname(name)
  end

  def build_path(name) do
    Application.app_dir(:up_img, ["priv", "static", "image_uploads", name])
  end

  # def thumb_name(name), do: Path.rootname(name) <> "-th" <> Path.extname(name)
  def thumb_name(name), do: Path.rootname(name) <> "-th" <> ".webp"

  def error_to_string(:too_large), do: "Too large."
  def error_to_string(:not_accepted), do: "You have selected an unacceptable file type."
  def error_to_string(:too_many_files), do: "You uploaded too many files"
  # coveralls-ignore-start
  def error_to_string(:external_client_failure),
    do: "Couldn't upload files to S3. Open an issue on Github and contact the repo owner."
end

# entry -
# %Phoenix.LiveView.UploadEntry{
#   progress: 100,
#   preflighted?: true,
#   upload_config: :image_list,
#   upload_ref: "phx-F4NSgF6BAJ2Dng8C",
#   ref: "0",
#   uuid: "808e6ae7-c6fe-4f8e-acdb-812497b4fe0f",
#   valid?: true,
#   done?: true,
#   cancelled?: false,
#   client_name: "Screenshot 2023-06-06 at 17.52.01.png",
#   client_relative_path: "",
#   client_size: 99767,
#   client_type: "image/png",
#   client_last_modified: 1686066727004
# }
