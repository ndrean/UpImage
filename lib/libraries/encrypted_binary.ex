defmodule UpImg.Encrypted.Binary do
  use Cloak.Ecto.Binary, vault: UpImg.MyVault
end
