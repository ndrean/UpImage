import Config

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :up_img, UpImg.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "up_img_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :up_img, UpImgWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "+USU+G6F6x6v5HQ74wp8+XKDLHyv9mKO6SusfEIv+dOXfhNHiEct0CyKdmHXrYyh",
  server: false

# In test we don't send emails.
# config :up_img, UpImg.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters.
# config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime


config :ex_aws,
  access_key_id: "AWS_ACCESS_KEY_ID",
  secret_access_key: "AWS_SECRET_ACCESS_KEY",
  region: "AWS_REGION",
  bucket: "AWS_S3_BUCKET",
  request_config_override: %{}

config :up_img, :github,
  github_client_id: "GITHUB_CLIENT_ID",
  github_client_secret: "GITHUB_CLIENT_SECRET"

config :up_img, :google,
  google_client_id: "GOOGLE_CLIENT_ID",
  google_client_secret: "GOOGLE_CLIENT_SECRET"

config :up_img, :vault_key, "CLOAKKEY"
