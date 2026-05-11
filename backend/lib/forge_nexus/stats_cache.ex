defmodule ForgeNexus.StatsCache do
  @moduledoc """
  ETS-backed cache for precomputed community stats.
  Updated every 5 minutes by the StatsComputer Oban cron worker.
  Serves dashboard, homepage, and widget data without hitting the DB.
  """
  use GenServer

  @table :forge_nexus_stats_cache

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @impl true
  def init(:ok) do
    :ets.new(@table, [:set, :public, :named_table, read_concurrency: true])
    {:ok, %{}}
  end

  @doc "Get a cached stat. Returns default if not yet computed."
  def get(key, default \\ nil) do
    case :ets.lookup(@table, key) do
      [{^key, value}] -> value
      [] -> default
    end
  rescue
    ArgumentError -> default
  end

  @doc "Store a precomputed stat."
  def put(key, value) do
    :ets.insert(@table, {key, value})
  rescue
    ArgumentError -> :ok
  end

  @doc "Get all cached stats as a map."
  def all do
    :ets.tab2list(@table) |> Map.new()
  rescue
    ArgumentError -> %{}
  end
end
