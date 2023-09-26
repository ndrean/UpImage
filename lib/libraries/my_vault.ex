defmodule UpImg.MyVault do
  @moduledoc """
  Configure the vault
  """
  use Cloak.Vault, otp_app: :up_img

  @impl GenServer
  def init(config) do
    config =
      Keyword.put(config, :ciphers,
        default: {
          Cloak.Ciphers.AES.GCM,
          tag: "AES.GCM.V1", key: decode_env!(), iv_length: 12
        }
      )

    {:ok, config}
  end

  defp decode_env! do
    case Application.fetch_env!(:up_img, :env) do
      :test ->
        Base.decode64!("T+mxlmxWbbyTByhybBYuMejOxsa6caeka3MvHEaci1A=")

      _ ->
        UpImg.vault_key() |> Base.decode64!()
    end
  end
end
