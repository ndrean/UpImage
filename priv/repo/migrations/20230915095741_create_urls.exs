defmodule UpImg.Repo.Migrations.CreateUrls do
  use Ecto.Migration

  def change do
    create table(:urls) do
      add :origin_url, :string
      add :resized_url, :string
      add :thumb_url, :string
      add :key, :string
      add :uuid, :uuid
      add :ext, :string
      add :user_id, references(:users, on_delete: :delete_all), null: false

      timestamps()
    end
  end
end
