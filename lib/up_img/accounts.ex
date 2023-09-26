defmodule UpImg.Accounts do
  # import Ecto.Changeset
  import Ecto.Query

  # alias UpImg.Accounts.Identity
  alias UpImg.Accounts.User
  alias UpImg.Repo

  ## Database getters

  @doc """
  Gets a user by email.

  ## Examples

      iex> get_user_by_email("foo@example.com")
      %User{}

      iex> get_user_by_email("unknown@example.com")
      nil

  """
  def get_user_by_email(email) when is_binary(email) do
    Repo.get_by(User, email: email)
  end

  @doc """
  Gets a single user.

  Raises `Ecto.NoResultsError` if the User does not exist.

  ## Examples

      iex> get_user!(123)
      %User{}

      iex> get_user!(456)
      ** (Ecto.NoResultsError)

  """

  # def get_user!(id), do: Repo.get!(User, id)

  def get_user!(id), do: Repo.get!(User, id)

  def get_user_by!(fields), do: Repo.get_by!(User, fields)

  # def update_active_profile(%User{active_profile_user_id: same_id} = current_user, same_id) do
  #   current_user
  # end

  # def update_active_profile(%User{} = current_user, profile_uid) do
  #   {1, _} =
  #     Repo.update_all(from(u in User, where: u.id == ^current_user.id),
  #       set: [active_profile_user_id: profile_uid]
  #     )

  #   # broadcast!(
  #   #   current_user,
  #   #   %Events.ActiveProfileChanged{current_user: current_user, new_profile_user_id: profile_uid}
  #   # )

  #   %User{current_user | active_profile_user_id: profile_uid}
  # end

  ## User registration

  def get_user_by_provider(provider, email) when provider in ["github"] do
    query =
      from(u in User,
        where:
          u.provider == ^provider and
            u.hashed_email == ^email
      )

    Repo.one(query)
  end

  def get_user_by_provider(provider, email) when provider in ["google"] do
    query =
      from(u in User,
        where:
          u.provider == ^provider and
            u.hashed_email == ^email
      )

    Repo.one(query)
  end

  @doc """
  Registers a user from their GithHub information.
  """
  def register_github_user(info) do
    case get_user_by_provider("github", info["email"]) do
      nil ->
        info
        |> User.github_registration_changeset()
        |> Repo.insert()

      user ->
        {:ok, user}
    end
  end

  def register_google_user(profil) do
    case get_user_by_provider("google", profil.email) do
      nil ->
        profil
        |> User.google_registration_changeset()
        |> Repo.insert()

      user ->
        {:ok, user}
    end
  end
end
