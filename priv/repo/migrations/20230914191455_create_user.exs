defmodule UpImg.Repo.Migrations.CreateUser do
  use Ecto.Migration

  def change do
    execute "CREATE EXTENSION IF NOT EXISTS citext", ""

    create table(:users) do
      add :email, :binary, null: false
      add :hashed_email, :binary, null: false
      add :username, :string, null: false
      add :name, :string
      add :provider, :string
      add :confirmed_at, :naive_datetime

      timestamps()
    end

    create unique_index(:users, [:hashed_email])
  end
end
