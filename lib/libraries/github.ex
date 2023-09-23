defmodule UpImg.Github do
  @moduledoc """
  Module to authenticate via Github.
  Use Dwyls module later.
  """

  alias UpImg.EnvReader
  def client_id, do: EnvReader.gh_id()
  def secret, do: EnvReader.gh_secret()

  def authorize_url do
    state = UpImg.gen_secret()

    URI.append_query(
      URI.new!("https://github.com/login/oauth/authorize?"),
      URI.encode_query(state: state, client_id: client_id(), scope: "user:email")
    )
    |> URI.to_string()
  end

  def exchange_access_token(opts) do
    code = Keyword.fetch!(opts, :code)
    state = Keyword.fetch!(opts, :state)

    state
    |> fetch_exchange_response(code)
    |> fetch_user_info()
  end

  defp fetch_exchange_response(state, code) do
    resp =
      http(
        "github.com",
        "POST",
        "/login/oauth/access_token",
        [state: state, code: code, client_secret: secret()],
        [{"accept", "application/json"}]
      )

    with {:ok, resp} <- resp,
         %{"access_token" => token} <- Jason.decode!(resp) do
      {:ok, token}
    else
      {:error, _reason} = err -> err
      %{} = resp -> {:error, {:bad_response, resp}}
    end
  end

  defp fetch_user_info({:error, _reason} = error), do: error

  defp fetch_user_info({:ok, token}) do
    resp =
      http(
        "api.github.com",
        "GET",
        "/user",
        [],
        [{"accept", "application/vnd.github.v3+json"}, {"Authorization", "token #{token}"}]
      )

    case resp do
      {:ok, info} -> {:ok, Jason.decode!(info)}
      {:error, _reason} = err -> err
    end
  end

  defp http(host, method, path, query, headers, body \\ "") do
    {:ok, conn} = Mint.HTTP.connect(:https, host, 443)

    path = path <> "?" <> URI.encode_query([{:client_id, client_id()} | query])

    {:ok, conn, ref} =
      Mint.HTTP.request(
        conn,
        method,
        path,
        headers,
        body
      )

    receive_resp(conn, ref, nil, nil, false)
  end

  defp receive_resp(conn, ref, status, data, done?) do
    receive do
      message ->
        {:ok, conn, responses} = Mint.HTTP.stream(conn, message)

        {new_status, new_data, done?} =
          Enum.reduce(responses, {status, data, done?}, fn
            {:status, ^ref, new_status}, {_old_status, data, done?} -> {new_status, data, done?}
            {:headers, ^ref, _headers}, acc -> acc
            {:data, ^ref, binary}, {status, nil, done?} -> {status, binary, done?}
            {:data, ^ref, binary}, {status, data, done?} -> {status, data <> binary, done?}
            {:done, ^ref}, {status, data, _done?} -> {status, data, true}
          end)

        cond do
          done? and new_status == 200 -> {:ok, new_data}
          done? -> {:error, {new_status, new_data}}
          !done? -> receive_resp(conn, ref, new_status, new_data, done?)
        end
    end
  end
end
