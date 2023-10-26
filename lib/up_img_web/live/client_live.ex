defmodule UpImgWeb.ClientLive do
  use UpImgWeb, :live_view

  require Logger
  @upload_dir Application.app_dir(:up_img, ["priv", "static", "image_uploads"])

  @impl true
  def mount(_params, _session, socket) do
    File.mkdir_p!(@upload_dir)

    {:ok,
     socket
     |> assign(uploaded_files: [])
     |> assign(:refs, [])
     |> allow_upload(:images,
       accept: ~w(.jpeg .jpg .png .webp),
       max_entries: 6,
       chunk_size: 64_000,
       max_file_size: 5_000_000
     )}
  end

  @impl true
  def handle_event("validate", _p, socket), do: {:noreply, socket}

  def handle_event("save", _p, socket) do
    result =
      consume_uploaded_entries(socket, :images, fn %{path: path} = _meta,
                                                   %{client_name: name} = _entry ->
        tmp_path = FileUtils.copy_path_into(path, name)
        base = extract_base(name)

        result =
          cond do
            String.contains?(name, "m512.webp") ->
              task =
                tmp_path
                |> UpImg.run_prediction_task()

              %{base: base, pred_ref: task.ref, ml_name: name}

            String.contains?(name, "m200.webp") ->
              UpImg.Upload.upload_task(tmp_path, name)
              %{base: base}

            String.contains?(name, "m1440.webp") ->
              UpImg.Upload.upload_task(tmp_path, name)
              %{base: base}

            true ->
              nil
          end

        {:ok, result}
      end)

    {:noreply, assign(socket, :uploaded_files, merge_list(result, :base))}
  end

  def merge_list(list, key) do
    have_key = fn map, curr, key -> Map.get(map, key) == Map.get(curr, key) end

    find_curr_in_acc = fn acc, curr, key ->
      Enum.find(acc, fn map -> have_key.(map, curr, key) end)
    end

    list
    |> Enum.reduce([], fn curr, acc ->
      case find_curr_in_acc.(acc, curr, key) do
        nil ->
          [curr | acc]

        exists ->
          [Map.merge(exists, curr) | Enum.filter(acc, &(&1 != exists))]
      end
    end)
  end

  def extract_base(name) do
    [base | _] = String.split(name, "-")
    base
  end

  def handle_info({:DOWN, _ref, :process, _pid}, _reason, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_info({ref, {:ok, %{body: %{location: location, key: key}}}}, socket) do
    Process.demonitor(ref, [:flush])

    remove_safely(key)

    {:noreply, update(socket, :uploaded_files, &update_uploads(&1, location, key))}
  end

  def handle_info({ref, %{results: [%{text: label}]}}, socket) do
    Process.demonitor(ref, [:flush])

    key = find_key(socket.assigns.uploaded_files, ref)

    remove_safely(key)

    {:noreply, update(socket, :uploaded_files, &update_labels(&1, label, key))}
  end

  def remove_safely(path) do
    file = UpImg.build_path(path)

    case File.rm(file) do
      :ok ->
        :ok

      {:error, reason} ->
        Logger.warning(inspect(reason))
        :ok
    end
  end

  def update_uploads(list, location, key) do
    base = extract_base(key)

    list
    |> Enum.map(fn
      %{base: ^base} = el ->
        case String.contains?(key, "m200.webp") do
          true -> Map.merge(el, %{thumb: location})
          false -> Map.merge(el, %{full: location})
        end

      el ->
        el
    end)
  end

  def find_key(list, ref) do
    list
    |> List.flatten()
    |> Enum.find(&(&1.pred_ref == ref))
    |> Map.get(:ml_name)
  end

  def update_labels(list, label, key) do
    base = extract_base(key)

    list
    |> Enum.map(fn
      %{base: ^base} = el ->
        case String.contains?(key, "m512.webp") do
          true -> Map.merge(el, %{label: label})
          false -> el
        end

      el ->
        el
    end)
  end
end
