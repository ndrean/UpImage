defmodule UpImg.Gallery.Files do
  use Ecto.Schema
  # alias UpImg.Accounts.User
  alias UpImg.Accounts

  schema "files" do
    field :path, :string
    belongs_to :user, User
    timestamps()
  end

  def clean_his_rubbish(%{user_id: user_id, older_than: _time}) do
    # Accounts.get_user(user_id)
  end
end
