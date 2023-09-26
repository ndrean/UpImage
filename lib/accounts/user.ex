defmodule UpImg.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset
  alias UpImg.Accounts.User
  alias UpImg.Gallery.Url

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

  def google_registration_changeset(profil) do
    params = %{
      "email" => Map.get(profil, :email),
      "provider" => "google",
      "name" => Map.get(profil, :name),
      "username" => Map.get(profil, :given_name)
    }

    changeset =
      %User{}
      |> cast(params, [:email, :hashed_email, :name, :username, :provider])
      |> validate_required([:email, :name, :username, :provider])
      |> unique_constraint([:hashed_email, :provider], name: :hashed_email_provider)

    put_change(changeset, :hashed_email, get_field(changeset, :email))
  end

  @doc """
  A user changeset for github registration.
  """
  def github_registration_changeset(info) do
    params =
      %{
        "email" => info["email"],
        "provider" => "github",
        "name" => info["name"],
        "username" => info["login"]
      }

    changeset =
      %User{}
      |> cast(params, [:email, :hashed_email, :name, :username, :provider])
      |> validate_required([:email, :name, :username, :provider])
      |> unique_constraint([:hashed_email, :provider], name: :hashed_email_provider)

    put_change(changeset, :hashed_email, get_field(changeset, :email))
  end
end
