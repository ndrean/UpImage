defmodule ElixirGoogleCerts do
  @moduledoc """
  Elixir module to use Google One tap from a controller.
  """

  @g_certs1_url "https://www.googleapis.com/oauth2/v1/certs"
  @iss "https://accounts.google.com"

  @json_lib Phoenix.json_library()

  @doc """
  This is run after the plug "check_csrf".

  It takes a map with the JWT token and a nonce. It checks that
  the received nonce is equal to the emitted one, and deciphers the JWT
  against Google public key (PEM or JWK).


  ## Example

      ```
      iex> ElixirGoogleCerts.verfified_identity(%{jwt: received_jwt})
    ```

  It returns `{:ok, profile}` or `{:error, reason}`.
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
      {:error, reason} -> {:error, inspect(reason)}
    end
  end

  # no specific HTTP client
  defp fetch(url) do
    case :httpc.request(:get, {~c"#{url}", []}, [], []) do
      {:ok, {{_version, 200, _}, _headers, body}} ->
        {:ok, %{body: body}}

      error ->
        {:error, inspect(error)}
    end
  end

  # ---- Google checking recommendations
  @doc """
  Token is not expired. Returns `true` or `false`.
  """
  def not_expired(exp) do
    exp > DateTime.to_unix(DateTime.utc_now())
  end

  @doc """
  Checks the received nonce against the one set in the HTML.

  Returns `true` or `false`.
  """
  def check_nonce(nonce, g_nonce), do: nonce === g_nonce

  @doc """
  Confirm the received Google_Client_ID against the one stored in the app.

  Returns `true` or `false`.
  """
  def check_user(aud, azp) do
    aud == aud() || azp == aud()
  end

  @doc """
  Confirm the received issuer is the one stored in the app.

  Returns `true` or `false`.
  """
  def check_iss(iss), do: iss == @iss
  defp aud, do: System.get_env("GOOGLE_CLIENT_ID")
end
