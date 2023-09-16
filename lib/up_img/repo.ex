defmodule UpImg.Repo do
  use Ecto.Repo,
    otp_app: :up_img,
    adapter: Ecto.Adapters.Postgres
end
