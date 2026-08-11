defmodule ForgeNexus.Cache do
  @moduledoc """
  Lightweight in-process ETS cache with per-key TTL.

  Replaces Cachex (which isn't available offline) with a small API:

      ForgeNexus.Cache.get(key)
      ForgeNexus.Cache.put(key, value, ttl_ms: 30_000)
      ForgeNexus.Cache.delete(key)
      ForgeNexus.Cache.flush()

  Expired entries are evicted lazily on read and by a periodic sweep.
  """

  use GenServer

  @table __MODULE__
  @sweep_interval :timer.minutes(5)

  # -- Public API ------------------------------------------------------------

  def start_link(_opts \\ []) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def get(key) do
    now = System.monotonic_time(:millisecond)

    case safe_lookup(key) do
      [{^key, value, :infinity}] ->
        {:ok, value}

      [{^key, value, expires_at}] when expires_at > now ->
        {:ok, value}

      [{^key, _value, _expired}] ->
        :ets.delete(@table, key)
        {:ok, nil}

      [] ->
        {:ok, nil}
    end
  end

  def put(key, value, opts \\ []) do
    expires_at =
      case Keyword.get(opts, :ttl_ms) do
        nil -> :infinity
        ms when is_integer(ms) and ms > 0 -> System.monotonic_time(:millisecond) + ms
        _ -> :infinity
      end

    case :ets.whereis(@table) do
      :undefined ->
        {:error, :cache_not_started}

      _ ->
        :ets.insert(@table, {key, value, expires_at})
        {:ok, true}
    end
  end

  def delete(key) do
    if :ets.whereis(@table) != :undefined, do: :ets.delete(@table, key)
    :ok
  end

  def flush do
    if :ets.whereis(@table) != :undefined, do: :ets.delete_all_objects(@table)
    :ok
  end

  # -- GenServer -------------------------------------------------------------

  @impl true
  def init(_) do
    :ets.new(@table, [
      :named_table,
      :public,
      :set,
      read_concurrency: true,
      write_concurrency: true
    ])

    schedule_sweep()
    {:ok, %{}}
  end

  @impl true
  def handle_info(:sweep, state) do
    sweep()
    schedule_sweep()
    {:noreply, state}
  end

  defp sweep do
    now = System.monotonic_time(:millisecond)
    ms = {{:_, :_, :"$1"}, [{:andalso, {:is_integer, :"$1"}, {:<, :"$1", now}}], [true]}
    :ets.select_delete(@table, [ms])
  end

  defp schedule_sweep, do: Process.send_after(self(), :sweep, @sweep_interval)

  defp safe_lookup(key) do
    case :ets.whereis(@table) do
      :undefined -> []
      _ -> :ets.lookup(@table, key)
    end
  end
end
