defmodule UpImg.MyVault do
  use Cloak.Vault, otp_app: :up_img

  @impl GenServer
  def init(config) do
    config =
      Keyword.put(config, :ciphers,
        default: {
          Cloak.Ciphers.AES.GCM,
          tag: "AES.GCM.V1", key: decode_env!("CLOAK_KEY"), iv_length: 12
        }
      )

    {:ok, config}
  end

  defp decode_env!(var) do
    var
    |> System.get_env()
    |> Base.decode64!()
  end
end
