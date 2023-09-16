defmodule UpImg.Accounts.Identity do
  use Ecto.Schema
  import Ecto.Changeset

  alias UpImg.Accounts.{Identity, User}

  # providers

  @derive {Inspect, except: [:provider_token]}
  schema "identities" do
    field :provider, :string
    field :provider_token, :string
    field :provider_email, :string
    field :provider_login, :string
    field :provider_name, :string, virtual: true
    field :provider_id, :string

    belongs_to :user, User

    timestamps()
  end

  @doc """
  A user changeset for github registration.
  """
  def github_registration_changeset(info, primary_email, token) do
    params = %{
      "provider_token" => token,
      "provider_id" => to_string(info["id"]),
      "provider_login" => info["login"],
      "provider_name" => info["name"] || info["login"],
      "provider_email" => primary_email
    }

    %Identity{provider: "github"}
    |> cast(params, [
      :provider_token,
      :provider_email,
      :provider_login,
      :provider_name,
      :provider_id
    ])
    |> validate_required([:provider_token, :provider_email, :provider_name, :provider_id])
  end

  def google_registration_changeset(info, token) do
    params =
      %{
        "provider_token" => token,
        "provider_id" => to_string(info.id),
        "provider_login" => info.given_name,
        "provider_name" => info.name,
        "provider_email" => info.email
      }

    %Identity{provider: "google"}
    |> cast(params, [
      :provider_token,
      :provider_email,
      :provider_login,
      :provider_name,
      :provider_id
    ])
    |> validate_required([:provider_token, :provider_email, :provider_name, :provider_id])
  end
end
