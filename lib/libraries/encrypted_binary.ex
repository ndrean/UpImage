defmodule UpImg.Encrypted.Binary do
  @moduledoc false
  use Cloak.Ecto.Binary, vault: UpImg.MyVault
end
