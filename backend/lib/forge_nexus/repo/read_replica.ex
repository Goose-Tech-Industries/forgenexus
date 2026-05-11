defmodule ForgeNexus.Repo.ReadReplica do
  @moduledoc """
  Read-only replica for heavy queries (analytics, search, stats).
  Falls back to the primary Repo if READ_REPLICA_URL is not configured.

  Usage:
    ReadReplica.all(query)    # instead of Repo.all(query)
    ReadReplica.one(query)    # instead of Repo.one(query)

  Only used for read operations. Never use for writes.
  """
  use Ecto.Repo,
    otp_app: :forge_nexus,
    adapter: Ecto.Adapters.Postgres,
    read_only: true
end
