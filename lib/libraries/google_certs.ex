defmodule ElixirGoogleCerts do
  @moduledoc """
  Elixir module to use Google One tap from a controller. It uses Google public key in PEM format.

  It depends on the JOSE library.
  """

  require Logger

  @g_certs1_url "https://www.googleapis.com/oauth2/v1/certs"
  @iss "https://accounts.google.com"

  @json_lib Phoenix.json_library()

  @doc """
  This is run **after** the plug "check_csrf".

  It takes a map with the JWT token. It deciphers the JWT against Google public key (PEM).

  ## Example

      ```
      iex> ElixirGoogleCerts.verfified_identity(%{jwt: received_jwt})
      {:ok, profile} | {:error, reason}
    ```
  """

  def verified_identity(%{jwt: jwt}) do
    with {:ok,
    %{
      "exp" => exp,
      "sub" => sub,
      "name" => name,
      "email" => email,
      "given_name" => given_name
      } = claims} <-
        check_identity_v1(jwt),
        true <- not_expired(exp),
        true <- check_iss(claims["iss"]),
        true <- check_user(claims["aud"], claims["azp"]) do
          Logger.info(inspect(jwt))
      {:ok, %{email: email, name: name, id: sub, given_name: given_name}}
    else
      {:error, msg} -> {:error, msg}
      false -> {:error, :wrong_check}
    end
  end

  @doc """
  Uses the Google Public key in PEM format. Takes the JWT and returns `{:ok, profile}` or `{:error, reason}`
  """
  def check_identity_v1(jwt) do
    with {:ok, %{"kid" => kid, "alg" => alg}} <- Joken.peek_header(jwt),
         {:ok, %{body: body}} <- fetch(@g_certs1_url) do
      {true, %{fields: fields}, _} =
        body
        |> @json_lib.decode!()
        |> Map.get(kid)
        |> JOSE.JWK.from_pem()
        |> JOSE.JWT.verify_strict([alg], jwt)

      {:ok, fields}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp fetch(url) do
    case Finch.build(:get, url) |> Finch.request(UpImg.Finch) do
      {:ok, %{body: body}} ->
        {:ok, %{body: body}}

      error ->
        {:error, error}
    end
  end

  # no specific HTTP client: not valid with Fly.io
  # defp fetch(url) do
  #   case :httpc.request(:get, {~c"#{url}", []}, [], []) do
  #     {:ok, {{_version, 200, _}, _headers, body}} ->
  #       {:ok, %{body: body}}

  #     error ->
  #       {:error, inspect(error)}
  #   end
  # end

  # ---- Google checking recommendations

  defp not_expired(exp) do
    exp > DateTime.to_unix(DateTime.utc_now())
  end

  defp check_user(aud, azp) do
    aud == aud() || azp == aud()
  end

  defp check_iss(iss), do: iss == @iss
  defp aud, do: UpImg.google_id()
end
