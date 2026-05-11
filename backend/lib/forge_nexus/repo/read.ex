defmodule ForgeNexus.Repo.Read do
  @moduledoc """
  Smart read router — uses the read replica if configured, otherwise primary.
  Drop-in replacement for Repo for read-heavy queries.

  Usage:
    alias ForgeNexus.Repo.Read
    Read.all(query)
    Read.one(query)
  """

  def repo do
    if replica_configured?() do
      ForgeNexus.Repo.ReadReplica
    else
      ForgeNexus.Repo
    end
  end

  def all(queryable, opts \\ []), do: repo().all(queryable, opts)
  def one(queryable, opts \\ []), do: repo().one(queryable, opts)
  def one!(queryable, opts \\ []), do: repo().one!(queryable, opts)
  def exists?(queryable, opts \\ []), do: repo().exists?(queryable, opts)

  defp replica_configured? do
    Application.get_env(:forge_nexus, ForgeNexus.Repo.ReadReplica) != nil
  end
end
