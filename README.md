# UpImg

## Authentication/Authorization

Minimum friction: full authorization for authenticated users. Using `Github` or `Google One-Tap` authentication, no password required.

### Encrypt email and query it

The email is encrypted (this is reversible) and is not searchable (because repeating an encryption on an input will walways given a different output - ciphertext - thus unique, so you can never match it). Its hash version (via `:sha256`) is however searchable (because repeating a hash on an input will always give the same output - hash - and cannot be "unhashed" (ie reversed to plaintext), thus considered as "safe".

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
          tag: "AES.GCM.V1", key: decode_env!("CLOAK_KEY"), iv_length: 12
        }
      )

    {:ok, config}
  end

  defp decode_env!(var) do
    var
    |> System.get_env()
    |> Base.decode64!()
  end
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

:exclamation: Note that the migration (to Postgres) should use the type `:binary` and not `:string`.

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
```

A changeset for a provider is shown below. Don't pass in a hash of the email. This is enforced in te `put_change`.

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

## Image transformation: Vix Vips

Uses [Vix Vips](https://github.com/akash-akya/vix) (NIF based binding for `libvips`) to transform inputs into WEBP format, resize and produce thumbnails on the server.

All tasks and HTTP calls are concurent.

## Generate the Database migration schema

Postgres database to persist users' data and uploaded URLs.

```bash
mix ecto.gen.erd
dot -Tpng ecto_erd.dot > erd.png
```

![ERD](erd.png)

## Notes for dev mode

### Temporary saved on the server

The files are temporarily saved on the server. They are deleted when uploaded. After 10 miniutes of inactivity, the files are pruned.

### File change watch

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

### About configuration

To properly configure the app (with Google & Github & AWS credentials):

- set the env variables in ".env" (and run `source .env`),
- set up a keyword list with eg `config :my_app, :google, client_id: System.get_env(...)` in "/config/dev.exs" and "/config/runtime.exs".
- in the app, you then can call `Application.fetch_env!(:my_app, :google)|> Keyword.get(:client_id)`
- you can also use the helper `MyApp.config([main_key, secondary_keys...])`. It should raise if the runtime time is missing.

If you don't have a nested keyword list, a simple helper can be:

```elixir
#my_app.ex
def config([first, second]) do
  case Application.get_application(__MODULE__)
        |> Application.fetch_env!(first)
        |> Keyword.get(second) do
    nil -> raise "No config found for: #{first}, #{second}"
    res -> res
  end
end
```

### Serving SVG

To serve some SVGs located in "/priv/static/images" (as `<img src={~p"/my-svg.svg"}/>`) instead of polluting the HTML markup, you can add the SVG file in the "/priv/static/images" directory and append the static list that Phoenix will server:

```elixir
#my_app_web.ex
 def static_paths, do:
 ~w(assets fonts images favicon.ico robots.txt image_uploads)
```

To handle failed task in `Task.async_stream`, use `on_timeout: :kill_task` so that a failed task will send `{:exit, :timeout}`.

### About the **reset of Uploads**

One solution is to "reduce" and `cancel_upload` all the refs along the socket, then reset the "uploaded_files_locally" and send a message.

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

Files are named by their SHA256 hash so are (almost) unique.

### Unique file upload

You can't temporarilly upload several times the same file. You can however upload it several times but you will get a warning that you attempt to save the same file. It has to be unique (to save on space).
