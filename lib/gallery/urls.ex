defmodule UpImg.Gallery.Url do
  @moduledoc """
  The schema of the table "urls": the list of urls per user per uuid.
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias UpImg.Accounts.User
  alias UpImg.Gallery.Url
  @keys [:origin_url, :thumb_url, :resized_url, :key, :user_id, :ext, :uuid]

  schema "urls" do
    field :origin_url, :string
    field :thumb_url, :string
    field :resized_url, :string
    field :key, :string
    field :uuid, :binary_id
    field :ext, :string
    belongs_to :user, User

    timestamps()
  end

  @doc false
  def changeset(%Url{} = url, attrs) do
    url
    |> cast(attrs, @keys)
    |> validate_required([:thumb_url, :resized_url, :user_id])
    |> unique_constraint([:thumb_url, :user_id], name: :thumb_url_user_index)
  end

  def traverse(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
    |> Enum.reduce("", fn {_k, v}, _acc -> Enum.join(v) end)
  end
end
