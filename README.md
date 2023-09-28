# UpImg

This app uploads images to S3 and transforms them into WEBP format to save on bandwidth and storage.

You can use it in two ways:

## API

It exposes an GET endpoint <https://up-image.fly.dev/api> to which you adjoin a query string with the parameters "name" (a `:string`, the name you wnat ot give to your file), a "url" (which serves the picture you want) and possibly a width "w" and optionnal a height "h" if you want to change the ratio.

You receive a json response with a link to a resized WEBP picture from S3.

~~We use **[libmagic](https://packages.debian.org/sid/libmagic-dev)** via [gen_magic](https://github.com/evadne/gen_magic). It works with magic numbers. It needs a depency in the Dockerfile~~

We use [ExIamgeInfo](https://github.com/Group4Layers/ex_image_info) to recognize the type of data. It assures that we receive a file of type "image".

### Example

To upload the 4177x3832-5MB image <https://apod.nasa.gov/apod/image/2309/SteveMw_Clarke_4177.jpg> to S3, and convert it into a WEBP image of 700x632-31kB, you pass into the query string the "url", a "name" and possibly the new desired width "w".

```bash
curl  -X GET -H "Accept: application/json"  https://up-image.fly.dev/api?name=test_file&w=700&url=https://apod.nasa.gov/apod/image/2309/SteveMw_Clarke_4177.jpg

# {"error":":too_large"}
```

```bash
curl  -X GET -H "Accept: application/json"  https://up-image.fly.dev/api\?name\=test_file\&w\=1400\&url\=https://apod.nasa.gov/apod/image/2309/STSCI-HST-abell370_1797x2000.jpg

# {"url":"https://s3.eu-west-3.amazonaws.com/xxxx/test_file.webp"}
```

If successful, you will receive a json response: `{"url": "https://xxx.amazonaws.com/xxxx/new_file.webp}` or `{"error: reason}`. This link is valid 1 hour.

You are limited to 5Mb and images with dimension less than 4200x4000.

To use the API, you need to register and get a token from the webapp. Then you pass this token

### Stream downloads and save to file

While streaming down the data from the source, we simply write the chunk into a file. This file is a temporary file `Plug.Upload.random_file`. Note that we can also directly read the whole data from memory with `Vix.Vips.Image.new_from_buffer`.

```elixir
{:ok, path} = Plug.Upload.random_file("stream")

def stream_request_into(req, path) do
  {:ok, file} = File.open(path, [:binary, :write])

  streaming =
    Finch.stream(req, UpImg.Finch, nil, fn
      {:status, status}, _acc ->
        status

      {:headers, headers}, _acc ->
        headers

      {:data, data}, _acc ->
        :ok = IO.binwrite(file, data)
    end)

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

## Webapp

You select files and the server will produce a thumbnail (for the display) and a resized file. All will be WEBP and displayed in the browser.

[CanIUse-WEBP?](https://caniuse.com/webp)

Once you load images from your device, 2 transformations are made: a thumbnail (of max dimension 200px) and a resize into max **1440x726** (if needed).
The transformation is based on the image processing library [libvips](https://www.libvips.org/) via the Elixir extension [Vix.Vips](https://github.com/akash-akya/vix).

Since we want ot display/serve the image, the previews are saved on disk into temporary files.
They are waiting for your decision to upload the image to S3 or not.

These files are pruned after a few minutes of inactivity and if you navigate away.
A scrubber also cleans all "old" files (at most one hour old).

<img width="614" alt="Screenshot 2023-09-27 at 16 51 05" src="https://github.com/ndrean/UpImage/assets/6793008/0838f94e-c216-442e-8864-9ef04d0e9eab">

## Authentication/Authorization

Minimum friction: full authorization for authenticated users. You can use `Github` or `Google One-Tap` authentication; no password is required as it is a "find_or_create" process.

## Image transformation: Vix Vips

It uses [Vix Vips](https://github.com/akash-akya/vix) (NIF based binding for `libvips`) to transform inputs into WEBP format, resize and produce thumbnails on the server from a binary.

All tasks are run concurently.

- The uploader writer has been changed to `ChunkWirter` to deliver an in-memory binary to avoid writting to disk.
- the binary is loaded by **Vix** with `Vix.Vips.Image.new_from_buffer`
- we then produce a thumbnail with `Vix.Vips.Operation.thumbnail_image`
- we also resize it with `Vix.Vips.resize` once we get the max full-screen size of the device via a Javascript hook.
- we finish the job by temporarily saving both files on disk into WEBP format with `Vix.Vipx.Operation.webpsave`.

### Custom UploadWriter

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

## Database migration schema

Postgres database to persist users' data and uploaded URLs.

```bash
mix ecto.gen.erd
dot -Tpng ecto_erd.dot > erd.png
```

![ERD](erd.png)

## Notes

### About configuration

To properly configure the app (with Google & Github & AWS credentials):

- set the env variables in ".env" (and run `source .env`),
- env vars are set up as a keyword list with eg `config :my_app, :google, client_id: System.get_env(...)` in "/config/runtime.exs" and "/config/dev/exs" and "/config/test/exs".
- only hardcoded configuration is set up in "/config/config.exs", such as Google or Github callback URI (which is also set in the router).
- in the app, most of the env vars are passed via a Task (`EnvReader`) into an ETS table to accelerate the reading. You get for example `EnvReader.google_id()`.

#### Fly.io setup

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

The Postgres database is generated by Fly.io. You will get the safe string to connect to the database.

### Startup Fly.io

<img width="985" alt="Screenshot 2023-09-27 at 14 40 07" src="https://github.com/ndrean/UpImage/assets/6793008/d11cfaff-16be-4847-9d13-52823e912fbe">

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
@derive {Inspect, except: [:email]}
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

- Create credentials for Google: <https://console.cloud.google.com/apis/credentials/> and pass Authorized Javascript origins and Authorized redirects URLs.

  <img width="484" alt="Screenshot 2023-09-19 at 21 07 17" src="https://github.com/ndrean/UpImage/assets/6793008/85da0045-6ca2-4726-a6d1-66fa4e8bb56f">

- set up callback URI for both, once you get the app URL (http://localhost:4000 firstly, then https://up-image.fly.dev once deployed)

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

:exclamation: Put no more than **one** per tag, usually a `<div>`, and place it in the beginning of the HTML markdown. You can create a `<div>` for this ‼️if needed.

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

### File names: SHA256

Files are named by their SHA256 hash (with `:crypto_hash`) so file names are (almost) unique.

### Unique file upload

You can't temporarilly upload several times the same file. You can however upload it several times but you will get a warning that you attempt to save the same file. It has to be unique (to save on space).

## Fly.io

### Postgres database

Example of credentials:

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
