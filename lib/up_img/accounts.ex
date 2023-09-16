defmodule UpImg.Accounts do
  import Ecto.Query
  import Ecto.Changeset

  alias UpImg.Repo
  alias UpImg.Accounts.Identity
  alias UpImg.Accounts.User

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
  def get_user!(id), do: Repo.get!(User, id)

  def get_user(id), do: Repo.get(User, id)

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

  def get_user_by_provider(provider, email) when provider in [:github] do
    query =
      from(u in User,
        join: i in assoc(u, :identities),
        where:
          i.provider == ^to_string(provider) and
            fragment("lower(?)", u.email) == ^String.downcase(email)
      )

    Repo.one(query)
  end

  def get_user_by_provider(provider, email) when provider in [:google] do
    query =
      from(u in User,
        join: i in assoc(u, :identities),
        where:
          i.provider == ^to_string(provider) and
            fragment("lower(?)", u.email) == ^String.downcase(email)
      )

    Repo.one(query)
  end

  @spec register_github_user(binary, any, any) :: any
  @doc """
  Registers a user from their GithHub information.
  """
  def register_github_user(primary_email, info, token) do
    if user = get_user_by_provider(:github, primary_email) do
      update_github_token(user, token)
    else
      info
      |> User.github_registration_changeset(primary_email, token)
      |> Repo.insert()
    end
  end

  def register_google_user(profil, token) do
    if user = get_user_by_provider(:google, profil.email) do
      update_google_token(user, token)
    else
      profil
      |> User.google_registration_changeset(token)
      |> Repo.insert()
    end
  end

  defp update_google_token(%User{} = user, token) do
    identity =
      Repo.one!(from(i in Identity, where: i.user_id == ^user.id and i.provider == "google"))

    {:ok, _} =
      identity
      |> change()
      |> put_change(:provider_token, token)
      |> Repo.update()

    {:ok, Repo.preload(user, :identities, force: true)}
  end

  defp update_github_token(%User{} = user, new_token) do
    identity =
      Repo.one!(from(i in Identity, where: i.user_id == ^user.id and i.provider == "github"))

    {:ok, _} =
      identity
      |> change()
      |> put_change(:provider_token, new_token)
      |> Repo.update()

    {:ok, Repo.preload(user, :identities, force: true)}
  end
end
