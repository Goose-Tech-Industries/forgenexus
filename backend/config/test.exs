import Config

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :forge_nexus, ForgeNexus.Repo,
  username: System.get_env("PGUSER") || "postgres",
  password:
    System.get_env("PGPASSWORD") ||
      (case File.read("/root/.goose_pg_password") do
         {:ok, pw} -> String.trim(pw)
         _ -> "postgres"
       end),
  hostname: System.get_env("PGHOST") || "localhost",
  port: String.to_integer(System.get_env("PGPORT") || "5432"),
  database: "forge_nexus_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :forge_nexus, ForgeNexusWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "pVqSF4tFJ8CGFLE9/Q7LNDvklogTjFv7zowqPafUWaaolcZa5RfJntydBoY3yACc",
  server: false

# In test we don't send emails
config :forge_nexus, ForgeNexus.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Sort query params output of verified routes for robust url comparisons
config :phoenix,
  sort_verified_routes_query_params: true
