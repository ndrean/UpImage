defmodule UpImg.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset
  alias UpImg.Accounts.Identity
  alias UpImg.Accounts.User
  alias UpImg.Gallery.Url

  schema "users" do
    field :email, :string
    field :name, :string
    field :username, :string
    field :confirmed_at, :naive_datetime

    has_many :identities, Identity

    has_many :urls, Url
    timestamps()
  end

  def google_registration_changeset(profil, token) do
    identity_changeset = Identity.google_registration_changeset(profil, token)

    if identity_changeset.valid? do
      params = %{
        "username" => profil.given_name,
        "email" => profil.email,
        "name" => get_change(identity_changeset, :provider_name)
      }

      %User{}
      |> cast(params, [:email, :name, :username])
      |> validate_required([:email, :name, :username])
      |> put_assoc(:identities, [identity_changeset])
    else
      %User{}
      |> change()
      |> Map.put(:valid?, false)
      |> put_assoc(:identities, [identity_changeset])
    end
  end

  @doc """
  A user changeset for github registration.
  """
  def github_registration_changeset(info, primary_email, token) do
    %{"login" => username} = info

    identity_changeset =
      Identity.github_registration_changeset(info, primary_email, token)

    if identity_changeset.valid? do
      params = %{
        "username" => username,
        "email" => primary_email,
        "name" => get_change(identity_changeset, :provider_name)
      }

      %User{}
      |> cast(params, [:email, :name, :username])
      |> validate_required([:email, :name, :username])
      |> put_assoc(:identities, [identity_changeset])
    else
      %User{}
      |> change()
      |> Map.put(:valid?, false)
      |> put_assoc(:identities, [identity_changeset])
    end
  end
end
