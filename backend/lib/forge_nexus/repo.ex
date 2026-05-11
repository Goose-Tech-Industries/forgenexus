defmodule ForgeNexus.Repo do
  use Ecto.Repo,
    otp_app: :forge_nexus,
    adapter: Ecto.Adapters.Postgres
end
