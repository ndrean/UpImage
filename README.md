# Table of contents, Up-Image

**STILL BUILDING**

- [Table of contents, Up-Image](#table-of-contents-up-image)
  - [About UpImg](#about-upimg)
  - [API](#api)
    - [GET endpoint](#get-endpoint)
    - [POST endpoint](#post-endpoint)
    - [Notes on Redirect and download in Streams](#notes-on-redirect-and-download-in-streams)
  - [Todos](#todos)
  - [WebApp](#webapp)
  - [Backend](#backend)
    - [Authentication, Authorization](#authentication-authorization)
    - [Encrypt email and query it](#encrypt-email-and-query-it)
    - [Credentials for Github, Google and AWS S3](#credentials-for-github-google-and-aws-s3)
    - [Database migration schema](#database-migration-schema)
    - [CSP](#csp)
  - [Image transformation: Vix Vips](#image-transformation-vix-vips)
  - [ML set up in Elixir](#ml-set-up-in-elixir)
  - [Notes](#notes)
    - [Notes on custom UploadWriter](#notes-on-custom-uploadwriter)
    - [Notes on Custom MultiPart to allow multiple file upload](#notes-on-custom-multipart-to-allow-multiple-file-upload)
    - [Streams of Uploads from S3](#streams-of-uploads-from-s3)
    - [Serving SVG](#serving-svg)
      - [Example: spinner](#example-spinner)
    - [Handle failed `Task.async_stream`](#handle-failed-taskasync_stream)
    - [**Reset of Uploads**](#reset-of-uploads)
    - [Process Supervision - restart: :transient](#process-supervision---restart-transient)
    - [Dev mode: file change watch](#dev-mode-file-change-watch)
    - [File names: SHA256](#file-names-sha256)
      - [Unique file upload](#unique-file-upload)
  - [About configuration](#about-configuration)
    - [Fly.io setup](#flyio-setup)
    - [Startup Fly.io](#startup-flyio)
    - [Temporary saved on the server](#temporary-saved-on-the-server)
    - [Example of credentials:](#example-of-credentials)
    - [IEx into the app](#iex-into-the-app)
  - [Sitemap](#sitemap)
  - [Cloudfare R2](#cloudfare-r2)

## About UpImg

This app uploads images to S3 and transforms them into WEBP format to save on bandwidth and storage. The transformation is based on [libvips](https://www.libvips.org/) and the Elixir package [Vix.Vips](https://github.com/akash-akya/vix).

Care is taken to maximise the usage of streams to limit the memory usage, especially when you upload multiple files. Care is taken to spawn processes whenever needed.

We propose an Image-To-Text implementation for **image tagging** or **caption creation** via a ML model. It proposes some tags and a caption to help the user to classify his pictures for him to retrieve them by tag. This might be a slow process, especially on a free-tier Fly.io machine. We set up the model with the env variable `MODEL`. It is built-in when the app starts.

About **[CanIUse-WEBP?](https://caniuse.com/webp)**

You can use this app in two ways: API and WebApp.

## API

It is limited to 5Mb images with dimension less than 4200x4000. The uploads are set with the `CONTENT-DISPOSITION="inline"`.

It exposes the two endpoints at <https://up-image.fly.dev/api>:

- a GET endpoint. It accepts a query string with the "url" (which serves the picture you want) and possibly and "w" (the desired width) and optionally "h" (the height if you want to change the ratio). It accepts **redirects**, such as unsplash urls (`https://source.unsplash.com/<photo_id>`).

- a POST endpoint. It accepts a payload with "multipart" - for **multiple** files with a FormData. Use the key **"w"** to specify the width to resize the file and the key "thumb" as a checkbox to produce a thumbnail (standard 100px). It also accepts a key **"pred"** if you want ot add a caption description found by the ML model.

They return a json response with a link to a resized WEBP picture from S3 along with informations on the original file and the new file.

We use two consecutive strategies to ensure that the upload is a picture.

- we firstly use **[libmagic](https://packages.debian.org/sid/libmagic-dev)** via [gen_magic](https://github.com/evadne/gen_magic). It works with **magic numbers**. It is added as a depency in the Dockerfile. We run this as a worker in order not to reload the C code on each call.

- if this test is positive, we then run [ExIamgeInfo](https://github.com/Group4Layers/ex_image_info) to confirm by matching on the type of data. It does not use magic number but rather reads the content of the file. Note that this gives a `Sobelow` warning since we read external data.

This should assure that we receive a file of type "image" with the desired format: `["webp", "jpeg", ""jpg"]`.

### GET endpoint

- GET: copy and paste an URL
  To upload the 4177x3832-5MB image <https://source.unsplash.com/QT-l619id6w> to S3, and convert it into a WEBP image of width=300, you pass into the query string the "url", and possibly the new desired width "w=70".

```bash
curl -X GET http://localhost:4000/api\?url\=https://source.unsplash.com/QT-l619id6w\&w\=300\&pred\=on
```

```bash
{"h":200,"w":300,"url":"https://dwyl-imgup.s3.eu-west-3.amazonaws.com/AA29E5B0.webp","init_size":213370,"w_origin":1080,"h_origin":720,"predictions":"paddle, boat paddle","new_size":14424,"url_origin":"https://source.unsplash.com/QT-l619id6w"}

```

If successful, you will receive a json response: `{"url": "https://xxx.amazonaws.com/xxxx/new_file.webp}` or `{"error: reason}`. This link is valid 1 hour.

### POST endpoint

You can use the POST endpoint simply with a `fetch({method: 'POST'})` from the browser.

A minimalist test: save the file below as "index.html" and `serve` it. You can select multiple files to upload to S3 to test the endpoint.

```html
<html>
  <body>
    <form
      id="f"
      action="https://up-image.fly.dev/api"
      method="POST"
      enctype="multipart/form-data"
    >
      <input type="file" name="file" multiple />
      <input type="number" name="w" />
      <button form="f">Upload</button>
    </form>

    <script>
      const form = ({ method, action } = document.forms[0]);
      form.onsubmit = async (e) => {
        e.preventDefault();
        return fetch(action, { method, body: new FormData(form) })
          .then((r) => r.json())
          .catch(console.log);
      };
    </script>
  </body>
</html>
```

You will receive a JSON response as a list:

```js
{"data":[
  {"h":39,"w":100,"url":"https://dwyl-imgup.s3.eu-west-3.amazonaws.com/0E3A7F41.webp","init_size":340362,"w_origin":1152,"h_origin":452,"new_size":5300,"filename":"test1"},
  {"h":68,"w":100,"url":"https://dwyl-imgup.s3.eu-west-3.amazonaws.com/F09F2736.webp","init_size":82234,"w_origin":960,"h_origin":656,"new_size":2028,"filename":"test2"}
  ]
}
```

### Notes on Redirect and download in Streams

We send a request and build a stream with the body since we want to write it into a file. This limits the memory usage.

When we have a [redirection](https://developer.mozilla.org/en-US/docs/Web/HTTP/Status/302), we get a status 302 and a header `Location`. We exploit this here.

```elixir
{:ok, path} = Plug.Upload.random_file("stream")

def follow_redirect(url, path) do
    Finch.build(:get, url)
    |> Api.stream_request_into(path)
end
```

```elixir
def stream_request_into(req, path) do
  {:ok, file} = File.open(path, [:binary, :write])

  streaming = stream_write(req, file)

  case File.close(file) do
    :ok ->
      case streaming do
        {:ok, _} ->
          {:ok, path}

        {:error, reason} ->
          {:error, reason}
      end

    {:error, reason} ->
      {:error, reason}
  end
end
```

We write into a file stream by stream. When we have a redirect, we have a `{"location", location}` header.
The function [Finch.stream](https://hexdocs.pm/finch/Finch.html#stream/5) uses 3 functions ahd each receives 2 arguments: a tuple and an accumulator. In the first function, we return the "status" as the accumulator. In the second function, we parse the headers and return the whole headers or the `Location` header depending if the acc = status = 302. The last function receives the headers in the accumulator. In the case where we have the value "location" in the `Location` header, we use recursion. If not, we write into the file so we do't return the whole binary.

<https://github.com/sneako/finch/blob/ff6a162174aa391cf4c7c7d6b59afb420cfec259/lib/finch.ex#L231>

A word on IOData : <https://elixirforum.com/t/understanding-iodata/3932/3>

```elixir

def follow_redirect(url, path) do
  Finch.build(:get, url)
  |> stream_request_into(path)
end

def stream_request_into(req, path) do
    {:ok, file} = File.open(path, [:binary, :write])

    streaming = stream_write(req, file)

    case File.close(file) do
      :ok ->
        case streaming do
          {:ok, _} ->
            {:ok, path}

          {:error, reason} ->
            {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end


def stream_write(req, file) do
    fun = fn
      {:status, status}, acc ->
        status

      {:headers, headers}, status ->
        handle_headers(headers, status)

      {:data, data}, headers ->
        handle_data(data, headers, file)
    end

    Finch.stream(req, UpImg.Finch, nil, fun)
  end

  defp handle_headers(headers, 302) do
    Enum.find(headers, &(elem(&1, 0) == "location"))
  end

  defp handle_headers(headers, 200) do
    headers
  end

  defp handle_headers(_headers, _status) do
    {:halt, "bad redirection"}
  end

  defp handle_data(_data, {"location", location}, file) do
    Finch.build(:get, location) |> Api.stream_write(file)
  end

  defp handle_data(_data, {:halt, "bad redirection"}, _file) do
    {:error, "bad redirection"}
  end

  defp handle_data(data, _headers, file) do
    case IO.binwrite(file, data) do
      :ok -> :ok
      {:error, reason} -> {:error, reason}
    end
  end
```

## Todos

- ~~implement One Tap newest version~~
- ~~"image caption" via ML~~
- ~~provide an API with GET via query string for URLS~~
- ~~capable of using redirected "unsplash" type URLs~~
- ~~provide an API with POST via FormData for mulitple files~~
- secure the API with a token provided by the app to a registered user. You can register simply via Google or Github, no friction. You then will request a token (valid 1 day).
- rate limit the API.
- implement a total MB uploaded per user.

## WebApp

You can use it in two ways:

- select files from your device you want to upload to S3,
- copy/paste a link of an image you want to upload to S3 (_UX en cours_)

You select files from your device and the server will produce a thumbnail (for the display) and a resized file. All will be WEBP and displayed in the browser.

Once you load images from your device, 2 transformations are made: a thumbnail (of max dimension 200px) and a resize into max **1440x726** (if needed).
The transformation is based on the image processing library [libvips](https://www.libvips.org/) via the Elixir extension [Vix.Vips](https://github.com/akash-akya/vix).

Since we want ot display/serve the image, the previews are saved on disk into temporary files.
They are waiting for your decision to upload the image to S3 or not.

These files are pruned after a few minutes of inactivity and if you navigate away.
A scrubber also cleans all "old" files (at most one hour old).

<img width="614" alt="Screenshot 2023-09-27 at 16 51 05" src="https://github.com/ndrean/UpImage/assets/6793008/0838f94e-c216-442e-8864-9ef04d0e9eab">

## Backend

### Authentication, Authorization

Minimum friction: full authorization for authenticated users. You can use `Github` or `Google One-Tap` authentication; no password is required as it is a "find_or_create" process.

Signin with [Google One Tap](https://developers.google.com/identity/gsi/web/guides/overview) now POST a `url-encoded` body instead of JSON. The code is updated to parse this.

### Encrypt email and query it

The email is encrypted (reversible) but is not searchable (because repeating an encryption on an input will walways given a different output - ciphertext - thus unique, so you can never match it). Its hash version (via `:sha256`) is however searchable because repeating a hash on an input will always give the same output, a hash. It _cannot_ -in terms of computation time, ie no better than a random search - be "unhashed" (ie reversed to plaintext), thus is considered as "safe".

[A blog on Erlang crypto](https://www.thegreatcodeadventure.com/elixir-encryption-with-erlang-crypto/)

[Very useful blog on email encryption and hash](https://github.com/dwyl/fields#why-do-we-have-both-emailencrypted-and-emailhash-)

We used: `[{:cloak, "~> 1.1"},{:cloak_ecto, "~> 1.2"}]` and `{:argon2_elixir, "~> 3.2"}`. Do not use `Bcrypt` because you want to be able to use a pre-defined hash to query the email.

[Usage of Cloak.Ecot.Binary](https://hexdocs.pm/cloak_ecto/Cloak.Ecto.Binary.html#content) to encrypt the email.

The salt is set by an env var. For the key rotation, read <https://github.com/dwyl/phoenix-ecto-encryption-example#33-key-rotation>

The (easiest) set up is:

```elixir
# Application.ex
children = [
  ...
  UpImg.MyVault
]

defmodule UpImg.Encrypted.Binary do
  use Cloak.Ecto.Binary, vault: UpImg.MyVault
end

defmodule UpImg.MyVault do
  use Cloak.Vault, otp_app: :up_img

  @impl GenServer
  def init(config) do
    config =
      Keyword.put(config, :ciphers,
        default: {
          Cloak.Ciphers.AES.GCM,
          tag: "AES.GCM.V1", key: decode_env!(), iv_length: 12
        }
      )

    {:ok, config}
  end

  defp decode_env!, do: System.get_env("CLOAK_KEY") |> Base.decode64!()
end
```

[Usage of the Ecto Type Cloak.Ecto.SHA256](https://hexdocs.pm/cloak_ecto/Cloak.Ecto.SHA256.html#module-usage)
The email is encrypted and the email is hashed. We use the Cloak special types for the Ecto schema

```elixir
schema "users" do
  field :email, UpImg.Encrypted.Binary
  field :hashed_email, Cloak.Ecto.SHA256
  field :provider, :string
  field :name, :string
  field :username, :string
  field :confirmed_at, :naive_datetime

  has_many :urls, Url
  timestamps()
end
```

:exclamation: Note that the migration (to Postgres) should use the type `:binary` and _not_ the type `:string`.

```elixir
# migration
create table(:users) do
  add :email, :binary, null: false
  add :hashed_email, :binary, null: false
  add :username, :string, null: false
  add :name, :string
  add :provider, :string
  add :confirmed_at, :naive_datetime

  timestamps()
end
create unique_index(:users, [:hashed_email, :provider], name: :hashed_email_provider)
```

A changeset for a provider is shown below. Don't pass in a hash of the email. This is _enforced_ in the `put_change`.

```elixir
def google_registration_changeset(profil) do
  params = %{
    "email" => profil.email,
    "provider" => "google",
    "name" => profil.name,
    "username" => profil.given_name
  }

  changeset =
    %User{}
    |> cast(params, [:email, :hashed_email, :name, :username, :provider])
    |> validate_required([:email, :name, :username])
    |> unique_constraint([:hashed_email, :provider], name: :hashed_email_provider)

  put_change(changeset, :hashed_email, get_field(changeset, :email))
end
```

We can check if the user should be created or exists with the simple query:

```elixir
def get_user_by_provider(provider, email) when provider in ["github"] do
  query =
    from(u in User,
      where:
        u.provider == ^provider and
          u.hashed_email == ^email
    )

  Repo.one(query)
end
```

### Credentials for Github, Google and AWS S3

- Create credentials for Github: <https://github.com/settings/developers> and pass callback URL

<img width="666" alt="Screenshot 2023-09-19 at 21 09 22" src="https://github.com/ndrean/UpImage/assets/6793008/35f41cc6-e8ba-4536-8384-d236fbe0d133">

- Create credentials for Google: <https://console.cloud.google.com/apis/credentials/> and pass Authorized Javascript origins and Authorized redirects URLs. The local set up is shown below (!! you need `http://localhost:4000` AND `http://localhost` in the authorised Javascript origin).

<img width="478" alt="Screenshot 2023-10-05 at 14 05 32" src="https://github.com/ndrean/UpImage/assets/6793008/6f1ecd68-e2c8-4587-a039-d5c46277debb">

- set up callback URI for both,
- come back to theses settings once you get the app deployed (https://up-image.fly.dev)

### Database migration schema

Postgres database to persist users' data and uploaded URLs.

```bash
mix ecto.gen.erd
dot -Tpng ecto_erd.dot > erd.png
```

![ERD](erd.png)

### CSP

Following `Sobelow` and Google's recommendations, a Content-Security-Policy is set up in the browser pipeline (don't put a "newline" as in the example below).

```elixir
plug :put_secure_browser_headers,
  %{
    "content-security-policy" =>
      "img-src data: w3.org/svg/2000 'self' https://*.googleapis.com/ https://s3.eu-west-3.amazonaws.com/; connect-src 'self' https://www.googleapis.com/oauth2 https://accounts.google.com;
      script-src-elem https://www.googleapis.com/oauth2 https://accounts.google.com 'self';
      frame-src 'self' https://accounts.google.com;
      style-src-elem https://accounts.google.com 'self' 'unsafe-inline';
      default-src 'self'"
  }
```

A [blog about CSP and Elixir](https://furlough.merecomplexities.com/elixir/phoenix/security/2021/02/26/content-security-policy-configuration-in-phoenix.html)

## Image transformation: Vix Vips

It uses [Vix Vips](https://github.com/akash-akya/vix) (NIF based binding for `libvips`) to transform inputs into WEBP format, resize and produce thumbnails on the server from a binary.

We target the device dimensions to respond. We produce 3 files: a thumbnail of max dim 200px, a file resized to 1440x??? (ratio preserved), and a file adapted to the device.

All tasks are run concurently.

- The uploader writer has been changed to `ChunkWirter` to deliver an in-memory binary to avoid writting to disk.
- the binary is loaded by **Vix** with `Vix.Vips.Image.new_from_buffer`
- we then produce a thumbnail with `Vix.Vips.Operation.thumbnail_image`
- we also resize it with `Vix.Vips.resize` once we get the max full-screen size of the device via a Javascript hook.
- we finish the job by temporarily saving both files on disk into WEBP format with `Vix.Vipx.Operation.webpsave`.

## ML set up in Elixir

## Notes

### Notes on custom UploadWriter

We want to pass a binary in memory instead of a random tmp file on disk. We re-write the [UploadWriter](https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.UploadWriter.html) passed in `allow_upload/3` under the option `:writer`. We want to do this because `Vix.Vips` can read from buffer so this saves on I/O.

```elixir
defmodule ChunkWriter do
 @behaviour Phoenix.LiveView.UploadWriter
  require Logger

  @impl true
  def init(_opts) do
    {:ok, %{file: ""}}
  end

  # it sends back the "meta"
  @impl true
  def meta(state), do: state

  @impl true
  def write_chunk(chunk, state) do
    {:ok, Map.update!(state, :file, &(&1 <> chunk))}
  end

  @impl true
  def close(state, :done) do
    {:ok, state}
  end

  def close(state, reason) do
    Logger.error("Error writer-----#{inspect(reason)}")
    {:ok, Map.put(state, :errors, inspect(reason))}
  end
end
```

### Notes on Custom MultiPart to allow multiple file upload

Phoenix accepts multipart encoded (`FormData`) and sets up a `Plug.Upload` mechanism to write a temporary file on disk. It only accepts one file since it uses the same key.

To change this to accept multiple files, one way is to create multiple keys, one for each file. This can be done by building a [custom multiparser](https://hexdocs.pm/plug/Plug.Parsers.MULTIPART.html#module-multipart-to-params).

```elixir
defmodule Plug.Parsers.FD_MULTIPART do
  @multipart Plug.Parsers.MULTIPART

  def init(opts) do
    opts
  end

  def parse(conn, "multipart", subtype, headers, opts) do
    length = System.fetch_env!("UPLOAD_LIMIT") |> String.to_integer()
    opts = @multipart.init([length: length] ++ opts)
    @multipart.parse(conn, "multipart", subtype, headers, opts)
  end

  def parse(conn, _type, _subtype, _headers, _opts) do
    {:next, conn}
  end

  def multipart_to_params(parts, conn) do
    case filter_content_type(parts) do
      nil ->
        {:ok, %{}, conn}

      new_parts ->
        acc =
          for {name, _headers, body} <- Enum.reverse(new_parts),
              reduce: Plug.Conn.Query.decode_init() do
            acc -> Plug.Conn.Query.decode_each({name, body}, acc)
          end

        {:ok, Plug.Conn.Query.decode_done(acc, []), conn}
    end
  end

  def filter_content_type(parts) do
    # find the headers than contain "content-type"
    filtered =
      parts
      |> Enum.filter(fn
        {_, [{"content-type", _}, {"content-disposition", _}], %Plug.Upload{}} = part ->
          part

        {_, [_], _} ->
          nil
      end)

    l = length(filtered)

    case l do
      0 ->
        # we don't want to submit without files as the rest of the code breaks
        nil

      _ ->
        # extract the others
        other = Enum.filter(parts, fn elt -> !Enum.member?(filtered, elt) end)

        # get the key identifier name
        key = elem(hd(filtered), 0)
        # build a list of indexed identifiers from the key: "key1", "key2",...
        new_keys = keys = Enum.map(1..l, fn i -> key <> "#{i}" end)

        # we do the following below: we change [{key, xxx,xxx}, {key,xxx,xxx}, ...] to
        # [{key1, xxx,xxx}, {key2,xxx,xxx},...] so we get unique identifiers
        f =
          Enum.zip_reduce([filtered, new_keys], [], fn elts, acc ->
            [{_, headers, content}, new_key] = elts
            [{new_key, headers, content} | acc]
          end)

        f ++ other
    end
  end
end
```

Then you declare it in the router in the `API` pipeline.

```elixir
#router.ex
pipeline :api do
  plug :accepts, ["json"]

  plug CORSPlug,
    origin: ["http://localhost:3000", "http://localhost:4000", "https://dwyl-upimage.fly.dev"]

  plug Plug.Parsers,
    parsers: [:urlencoded, :my_multipart, :json],
    pass: ["image/jpg", "image/png", "image/webp", "iamge/jpeg"],
    json_decoder: Jason,
    multipart_to_params: {Plug.Parsers.FD_MULTIPART, :multipart_to_params, []},
    body_reader: {Plug.Parsers.FD_MULTIPART, :read_body, []}
end
```

### Streams of Uploads from S3

All the users' uploaded files are displayed as `streams``. To limit data usage, a thumbnail (5-10 kB) is displayed which links to the resized/webp format of the original image.

Notice that when we upload a file to S3, we save the URL returned by S3 into the database. We then display all the uploaded files from S3 for this user by inserting this file into the stream. We need to pass a `%Phoenix.LiveVew.UploadEntry{}` struct - populated by the up-to-date data received from S3 - for `stream.insert` to work.

```elixir
data =
  Map.new()
  |> Map.put(:resized_url, map.resized_url)
  |> Map.put(:thumb_url, map.thumb_url)
  |> Map.put(:uuid, map.uuid)
  |> Map.put(:user_id, current_user.id)

case Url.changeset(%Url{}, data) |> Repo.insert() do
  {:ok, _} ->
    new_file =
      %Phoenix.LiveView.UploadEntry{}
      |> Map.merge(data)

    {:noreply, stream_insert(socket, :uploaded_files_to_S3, new_file)}
```

### Serving SVG

You can serve SVGs located in "/priv/static/images" (as `<img src={~p"/my-svg.svg"}/>`) instead of polluting the HTML markup. Append the static list that Phoenix will server:

```elixir
#my_app_web.ex
 def static_paths, do:
 ~w(assets fonts images favicon.ico robots.txt image_uploads)
```

In the CSP, use: `"img-src w3.org/svg/2000;`

#### Example: spinner

Just followed this [excellent post](https://fly.io/phoenix-files/server-triggered-js/) from Fly.io.

A [repo](https://github.com/n3r4zzurr0/svg-spinners/tree/main) with simple SVG spinners; it is passed as `<img scr=path>` and the SVG is located in the "/priv/static/images" directory.

### Handle failed `Task.async_stream`

To handle failed task in `Task.async_stream`, use `on_timeout: :kill_task` so that a failed task will send `{:exit, :timeout}`.

### **Reset of Uploads**

In case a user loads a "bad" file", you will get an error. We are not in the case of managing errors within the form. One solution to handle this case is to "reduce" and `cancel_upload` all the refs along the socket, then reset the "uploaded_files_locally" and perhaps send a message that describes the error (too many files, too large). This will reset the users' entries.

```elixir
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
```

```elixir
def handle_info({:upload_error, error_list}, socket) do
  errors =
    error_list |> Enum.reduce([], fn {_ref, msg}, list -> [error_to_string(msg) | list] end)

  send(self(), {:cancel_upload})
  {:noreply, put_flash(socket, :error, inspect(errors))}
end
```

and then:

```elixir
def handle_info({:cancel_upload}, socket) do
  # clean the uploads
  socket =
    socket.assigns.uploads.image_list.entries
    |> Enum.map(& &1.ref)
    |> Enum.reduce(socket, fn ref, socket -> cancel_upload(socket, :image_list, ref) end)

  {:noreply, assign(socket, :uploaded_files_locally, [])}
end
```

### Process Supervision - restart: :transient

We want a process to be supervised and restart if fails, but we don't want this process to kill the parent LiveView. For example, when we ask to delete a file in S3, we don't want this to fail to avoid a difference with a database.

An example in a LiveBook:

```elixir
Supervisor.start_link(
  [
    {DynamicSupervisor, name: DynSup, strategy: :one_for_one},
    {Registry, keys: :unique, name: MyRegistry},
    {Task.Supervisor, name: MyTSup}
  ],
  strategy: :one_for_one,
  name: MySupervisor
)
{:ok, pid1} = Task.start(fn -> Process.sleep(10000); IO.puts "ok" end)
{:ok, pid2} = Task.Supervisor.start_child(MyTSup, fn -> Process.sleep(10000); IO.puts "ok sup" end, restart: :transient)
IO.inspect({pid1, pid2})

# check if pid2 is indeed supervised
Task.Supervisor.children(MyTSup)

# we kill pid2. The LV is not stopped, and pid2 will be restarted
Process.exit(pid2, :kill)

"ok"
"ok sup"
```

### Dev mode: file change watch

To stop rebuild when file changes, remove the folder "image_uploads" from the watched list by setting:

```elixir
# /config/dev.exs
config :up_img, UpImgWeb.Endpoint,
  live_reload: [
    patterns: [
      ~r"priv/static/[^image_uploads].*(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"priv/gettext/.*(po)$",
      ~r"lib/up_img_web/(controllers|live|components)/.*(ex|heex)$"
    ]
  ]
```

### File names: SHA256

Files are named by their SHA256 hash (with `:crypto_hash`) so file names are (almost) unique.

#### Unique file upload

We disabled the possibility to upload several times the same file. You can however upload it several times but you will get a warning that you attempt to save the same file. It has to be unique (to save on space).

## About configuration

To properly configure the app (with Google & Github & AWS credentials):

- set the env variables in ".env" (and run `source .env`),
- env vars are set up as a keyword list with eg `config :my_app, :google, client_id: System.get_env(...)` in "/config/runtime.exs" and "/config/dev/exs" and "/config/test/exs".
- only hardcoded configuration is set up in "/config/config.exs", such as Google or Github callback URI (which is also set in the router).
- in the app, most of the env vars are passed via a Task (`EnvReader`) into an ETS table to accelerate the reading. You get for example `EnvReader.google_id()`.

### Fly.io setup

You can copy your **.env** file (without `export`!) into the CLI and push your secrets:

```bash
fly secrets set <paste here> PORT=8080 ....
```

The list is:

- `PORT=8080`,
- `SECRET_KEY_BASE` (via `mix phx.gen.secret`)
- Github credentials generated [here](https://github.com/settings/developers): `GITHUB_CLIENT_ID`, `GITHUB_CLIENT_SECRET`,
- Google credentials [Google console](https://console.cloud.google.com/apis/credentials/): `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET`,
- the email encrypting process ("at rest") key: `CLOAK_KEY`, generated by `32 |> :crypto.strong_rand_bytes() |> Base.encode64()` (cf [doc](https://hexdocs.pm/cloak_ecto/generate_keys.html#content)),
- AWS S3 credentials: AWS_REGION`,`AWS_ACCESS_KEY_ID`, AWS_SECRET_ACCESS_KEY`, `AWS_S3_BUCKET`,
- configure the old file scrubbing service period (base 1 hour): `PERIOD=1`
- upload limit size: `UPLOAD_LIMIT=5000000`

The Postgres database is generated by Fly.io. You will get the safe string to connect to the database.

### Startup Fly.io

<img width="985" alt="Screenshot 2023-09-27 at 14 40 07" src="https://github.com/ndrean/UpImage/assets/6793008/d11cfaff-16be-4847-9d13-52823e912fbe">

### Temporary saved on the server

When the user previews files, they are temporarilly saved on the server.

When selected for upload to S3 (and uploaded), they are removed from the assigns and pruned from the disk.

Since a user may quit the tab, files will be hanging. We have 2 guards to prevent holding unnecessary files on the server.

We set a hook which implements a browser listener on the navigation link. When clicked, it triggers a server `pushEvent` to clean the temporary assigns and the corresponding files on disk.

After 10 minutes of inactivity **on a desktop**, the temporary files are pruned if the app is still open. This is run via a `hook` that runs a `setTimeout` in the browser when the upload tab is opened. A browser event resets the timeout. When triggered, it `pushEventTo` the server and cleans the temporary assigns and redirects.

:exclamation: The previous guard does not work on mobile.

We set a `Process.send_after` to clean the temporary files after 3 minutes (an Env Var). Every new preview cancels the timer and sets a new one. This works even when the app is set in the background.

Some edge cases may still remain. We run a reccurent task to remove all files older than one hour ago (with `File.stat`).

```elixir
#Application
children = [
  {Task,
  fn -> FileUtils.clean(every_ms: 1_000 * 60 * 60, older_than_seconds: 60 * 60 * 1) end}
]
```

! Put no more than **one** per tag, usually a `<div>`, and place it in the beginning of the HTML markdown. You can create a `<div>` for this ‼️if needed.

### Example of credentials:

```bash
Postgres cluster up-image-db created
Username: postgres
Password: <FLY_PWD>
Hostname: up-image-db.internal
Flycast: fdaa:0:57e6:0:1::4
Proxy port: 5432
Postgres port: 5433
Database_URL: <FLY_STRING>
```

### IEx into the app

<https://fly.io/docs/elixir/the-basics/iex-into-running-app/>

```bash
> fly ssh issue --agent
> fly ssh console --pty -C "/app/bin/up_img remote"

iex(up_img@683d47dcd65948)4>
Application.app_dir(:up_img, ["priv", "static", "image_uploads"]) |> File.ls!()
```

## Sitemap

<https://andrewian.dev/blog/sitemap-in-phoenix-with-verified-routes>
<https://medium.com/@ricardoruwer/create-dynamic-sitemap-xml-in-elixir-and-phoenix-6167504e0e4b>

## Cloudfare R2

Install the CLI.
Save your "keyID" and "applicationKey"

Save this file locally, named "b2_cors.json" here:

```json
[
  {
    "corsRuleName": "downloadFromAnyOrigin",
    "allowedOrigins": ["https", "http://localhost:4000"],
    "allowedHeaders": ["range"],
    "allowedOperations": [
      "b2_download_file_by_id",
      "b2_download_file_by_name",
      "b2_upload_file",
      "b2_upload_part",
      "s3_delete",
      "s3_get",
      "s3_post",
      "s3_put"
    ],
    "exposeHeaders": [
      "x-bz-content-sha1",
      "X-Bz-File-Name",
      "X-Bz-Part-Number"
    ],
    "maxAgeSeconds": 3600
  }
]
```

```bash
> b2 authorize-account <keyID> <applicationKey>
> b2 list-buckets
up-image
> b2 update-bucket --corsRules "$(<./b2_cors.json)" <bucket> allPublic
```

<https://dash.cloudflare.com/843179836f19f3543d8ed2866db92b5f/r2/cli?from=overview>

Run `pnpm create cladufare@latest`, choose a folder, say "r2", choose worker, and then `npx wrangler` to `npx wrangler r2 bucket create <name>`.

In CF/R2 dashboard, go to your bucket, and in "settings", in CORS-policy, add:

```json
[
  {
    "AllowedOrigins": [
      "http://localhost:3000",
      "http://localhost:4000",
      "https://up-image.fly.dev"
    ],
    "AllowedMethods": ["GET", "PUT", "POST"],
    "AllowedHeaders": ["*"],
    "ExposeHeaders": []
  }
]
```

```elixir
[
  %{
    base: "dff3a13e58c2fcb2d1382f8f016e035405bad359",
    full_ref: "#Reference<0.0.575235.90977385.2484928518.78414>",
    full_name: "dff3a13e58c2fcb2d1382f8f016e035405bad359-m1440.webp"
  },
  %{
    base: "dff3a13e58c2fcb2d1382f8f016e035405bad359",
    pred_ref: "#Reference<0.0.575235.90977385.2484928518.78487>",
    ml_name: "dff3a13e58c2fcb2d1382f8f016e035405bad359-m512.webp"
  },
  %{
    base: "dff3a13e58c2fcb2d1382f8f016e035405bad359",
    thumb_ref: "#Reference<0.0.575235.90977385.2484928518.78510>",
    thumb_name: "dff3a13e58c2fcb2d1382f8f016e035405bad359-m200.webp"
  },
  %{
    base: "1110df0436fd62b85bb8579695102f38ff034092",
    full_ref: "#Reference<0.0.575235.90977385.2484928515.120170>",
    full_name: "1110df0436fd62b85bb8579695102f38ff034092-m1440.webp"
  },
  %{
    base: "1110df0436fd62b85bb8579695102f38ff034092",
    pred_ref: "#Reference<0.0.575235.90977385.2484928515.120244>",
    ml_name: "1110df0436fd62b85bb8579695102f38ff034092-m512.webp"
  },
  %{
    base: "1110df0436fd62b85bb8579695102f38ff034092",
    thumb_ref: "#Reference<0.0.575235.90977385.2484928515.120256>",
    thumb_name: "1110df0436fd62b85bb8579695102f38ff034092-m200.webp"
  }
]

[
  %{
    base: "1110df0436fd62b85bb8579695102f38ff034092",
    pred_ref: "#Reference<0.0.575235.90977385.2484928515.120244>",
    thumb_ref: "#Reference<0.0.575235.90977385.2484928515.120256>",
    full_ref: "#Reference<0.0.575235.90977385.2484928515.120170>",
    ml_name: "1110df0436fd62b85bb8579695102f38ff034092-m512.webp",
    thumb_name: "1110df0436fd62b85bb8579695102f38ff034092-m200.webp",
    full_name: "1110df0436fd62b85bb8579695102f38ff034092-m1440.webp"
  },
  %{
    base: "dff3a13e58c2fcb2d1382f8f016e035405bad359",
    pred_ref: "#Reference<0.0.575235.90977385.2484928518.78487>",
    thumb_ref: "#Reference<0.0.575235.90977385.2484928518.78510>",
    full_ref: "#Reference<0.0.575235.90977385.2484928518.78414>",
    ml_name: "dff3a13e58c2fcb2d1382f8f016e035405bad359-m512.webp",
    thumb_name: "dff3a13e58c2fcb2d1382f8f016e035405bad359-m200.webp",
    full_name: "dff3a13e58c2fcb2d1382f8f016e035405bad359-m1440.webp"
  }
]

[
  %{
    full: "https://843179836f19f3543d8ed2866db92b5f.r2.cloudflarestorage.com/up-image/dff3a13e58c2fcb2d1382f8f016e035405bad359-m1440.webp",
    base: "dff3a13e58c2fcb2d1382f8f016e035405bad359",
    thumb: "https://843179836f19f3543d8ed2866db92b5f.r2.cloudflarestorage.com/up-image/dff3a13e58c2fcb2d1382f8f016e035405bad359-m200.webp",
    pred_ref: "#Reference<0.0.698115.90977385.2484928517.100235>",
    thumb_ref: "#Reference<0.0.698115.90977385.2484928517.100257>",
    full_ref: "#Reference<0.0.698115.90977385.2484928517.100172>",
    ml_name: "dff3a13e58c2fcb2d1382f8f016e035405bad359-m512.webp",
    thumb_name: "dff3a13e58c2fcb2d1382f8f016e035405bad359-m200.webp",
    full_name: "dff3a13e58c2fcb2d1382f8f016e035405bad359-m1440.webp"
    },
   %{
    full: "https://843179836f19f3543d8ed2866db92b5f.r2.cloudflarestorage.com/up-image/dff3a13e58c2fcb2d1382f8f016e035405bad359-m1440.webp",
    base: "dff3a13e58c2fcb2d1382f8f016e035405bad359",
    thumb: "https://843179836f19f3543d8ed2866db92b5f.r2.cloudflarestorage.com/up-image/dff3a13e58c2fcb2d1382f8f016e035405bad359-m200.webp",
    pred_ref: "#Reference<0.0.698115.90977385.2484928517.100235>",
    thumb_ref: "#Reference<0.0.698115.90977385.2484928517.100257>",
    full_ref: "#Reference<0.0.698115.90977385.2484928517.100172>",
    ml_name: "dff3a13e58c2fcb2d1382f8f016e035405bad359-m512.webp",
    thumb_name: "dff3a13e58c2fcb2d1382f8f016e035405bad359-m200.webp",
    full_name: "dff3a13e58c2fcb2d1382f8f016e035405bad359-m1440.webp"
  }
]
```
