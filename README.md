# UpImg

This webapp uploads iagaes to S3 and transforms them into WEBP format to save on bandwidth and storage.

[CanIUse-WEBP?](https://caniuse.com/webp)

Once you load images from your device, 2 transformations are made: a thumbnail (of max dimension 200px) and a resize into max **1440x726** (if needed).
The transformation is based on the image processing library [libvips](https://www.libvips.org/) via the Elixir extension [Vix.Vips](https://github.com/akash-akya/vix).

Since we want ot display/serve the image, the previews are saved on disk into temporary files.
They are waiting for your decision to upload the image to S3 or not.

These files are pruned after a few minutes of inactivity and if you navigate away.
A scrubber also cleans all "old" files (at most one hour old).

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

All the users' uploaded files are displayed as streams. To limit data usage, a thumbnail (5-10 kB) is displayed which links to the resized/webp format of the original image.

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
