defmodule ElixirGoogleCerts do
  @moduledoc """
  Elixir module to use Google One tap from a controller. It uses Google public key in PEM format.

  It depends on the JOSE library.
  """

  @g_certs1_url "https://www.googleapis.com/oauth2/v1/certs"
  @iss "https://accounts.google.com"

  @json_lib Phoenix.json_library()
  @registered_http_client Application.compile_env!(:up_img, :http_client)

  @doc """
  This runs **after** the plug `UpImg.CheckCsrf.

  It takes a map with the JWT token. It deciphers the JWT against Google public key (PEM).

  ## Example

      ```
      iex> ElixirGoogleCerts.verfified_identity(%{jwt: received_jwt})
      {:ok, profile} | {:error, reason}
    ```
  """

def verified_identity(%{jwt: jwt}) do
  with {:ok, profile} <- check_identity_v1(jwt),
       {:ok, true} <- run_checks(profile) do
    {:ok, profile}
  else
    {:error, msg} -> {:error, msg}
  end
end

  @doc """
  Uses the Google Public key in PEM format. Takes the JWT and returns `{:ok, profile}` or `{:error, reason}`
  """
  def check_identity_v1(jwt) do
    with {:ok, %{"kid" => kid, "alg" => alg}} <- Joken.peek_header(jwt),
         {:ok, body} <- fetch(@g_certs1_url) do
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
    case Finch.build(:get, url) |> Finch.request(@registered_http_client) do
      {:ok, %{body: body}} ->
        {:ok, body}

      error ->
        {:error, error}
    end
  end

  # HTTP client used :http to limit dependencies. Cf https://elixirforum.com/t/httpc-cheatsheet/50337
  # defp fetch(url) do
  #   :inets.start()
  #   :ssl.start()
  #   # headers = [{~c"accept", ~c"application/x-www-form-urlencoded"}]
  #   headers = [{~c"accept", ~c"application/json"}]

  #   http_request_opts = [
  #     ssl: [
  #       verify: :verify_peer,
  #       cacerts: :public_key.cacerts_get(),
  #       customize_hostname_check: [
  #         match_fun: :public_key.pkix_verify_hostname_match_fun(:https)
  #       ]
  #     ]
  #   ]

  #   case :httpc.request(:get, {~c"#{url}", headers}, http_request_opts, []) do
  #     {:ok, {{_version, 200, _}, headers, body}} ->
  #       headers |> dbg()
  #       {:ok, body}

  #     error ->
  #       {:error, error}
  #   end
  # end

  # ---- Google checking recommendations

  def run_checks(claims) do
    %{
      "exp" => exp,
      "aud" => aud,
      "azp" => azp,
      "iss" => iss
    } = claims

    with {:ok, true} <- not_expired(exp),
         {:ok, true} <- check_iss(iss),
         {:ok, true} <- check_user(aud, azp) do
      {:ok, true}
    else
      {:error, message} -> {:error, message}
    end
  end

  def not_expired(exp) do
    new_exp = 1_314_000_000 + exp

    exp =
      if Application.get_env(:up_img, :env) == :test,
        do: new_exp,
        else: exp

    case exp > DateTime.to_unix(DateTime.utc_now()) do
      true -> {:ok, true}
      false -> {:error, :expired}
    end
  end

  def check_user(aud, azp) do
    g_id =
      if Application.get_env(:up_img, :env),
        do: "458400071137-gvjpbma9909fc9r4kr131vlm6sd4tp9g.apps.googleusercontent.com",
        else: UpImg.EnvReader.google_id()

    case aud == g_id || azp == g_id do
      true -> {:ok, true}
      false -> {:error, :wrong_id}
    end
  end

  def check_iss(iss) do
    case iss == @iss do
      true -> {:ok, true}
      false -> {:error, :wrong_issuer}
    end
  end

  defp app_id, do: System.get_env("GOOGLE_CLIENT_ID")

end
