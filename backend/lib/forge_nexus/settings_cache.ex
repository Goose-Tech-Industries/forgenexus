defmodule ForgeNexus.SettingsCache do
  @moduledoc """
  ETS-backed cache for site_settings.
  Prevents a DB query on every single request for public settings.
  TTL: 30 seconds. Invalidated on write via Settings.set/2.
  """
  use GenServer

  @table :forge_nexus_settings_cache
  @ttl_ms 30_000

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @doc "Get a cached value, falling back to the loader function."
  def get(key, loader_fn) do
    now = System.monotonic_time(:millisecond)

    case :ets.lookup(@table, key) do
      [{^key, value, expires_at}] when expires_at > now ->
        value

      _ ->
        value = loader_fn.()
        :ets.insert(@table, {key, value, now + @ttl_ms})
        value
    end
  end

  @doc "Invalidate a specific key."
  def invalidate(key) do
    :ets.delete(@table, key)
  rescue
    ArgumentError -> :ok
  end

  @doc "Invalidate all cached settings."
  def invalidate_all do
    :ets.delete_all_objects(@table)
  rescue
    ArgumentError -> :ok
  end

  @impl true
  def init(:ok) do
    :ets.new(@table, [:set, :public, :named_table, read_concurrency: true])
    {:ok, %{}}
  end
end
