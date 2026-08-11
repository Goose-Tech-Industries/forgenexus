defmodule ForgeNexus.PresenceTracker do
  @moduledoc """
  ETS-backed presence tracker for fast online user lookups.
  Complements Phoenix.Presence (WebSocket) with API-level tracking.

  Tracks:
  - user_id, username, avatar_url
  - last_seen timestamp
  - current_page (optional — what forum/thread they're viewing)

  Prunes stale entries every 30 seconds (users not seen in 5 minutes).
  """
  use GenServer

  @table :forge_nexus_presence
  @stale_after_ms :timer.minutes(5)
  @prune_interval_ms :timer.seconds(30)

  # --- Public API ---

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @doc "Track a user as online. Call on any API request or WebSocket heartbeat."
  def track(user_id, meta \\ %{}) do
    now = System.monotonic_time(:millisecond)

    entry = %{
      user_id: user_id,
      username: Map.get(meta, :username),
      avatar_url: Map.get(meta, :avatar_url),
      current_page: Map.get(meta, :current_page),
      last_seen: now
    }

    :ets.insert(@table, {user_id, entry})
    :ok
  rescue
    ArgumentError -> :ok
  end

  @doc "Remove a user (on logout or WebSocket disconnect)."
  def untrack(user_id) do
    :ets.delete(@table, user_id)
    :ok
  rescue
    ArgumentError -> :ok
  end

  @doc "List all online users."
  def list_online do
    cutoff = System.monotonic_time(:millisecond) - @stale_after_ms

    :ets.tab2list(@table)
    |> Enum.filter(fn {_id, entry} -> entry.last_seen > cutoff end)
    |> Enum.map(fn {_id, entry} -> entry end)
  rescue
    ArgumentError -> []
  end

  @doc "Count of online users."
  def online_count do
    cutoff = System.monotonic_time(:millisecond) - @stale_after_ms

    :ets.tab2list(@table)
    |> Enum.count(fn {_id, entry} -> entry.last_seen > cutoff end)
  rescue
    ArgumentError -> 0
  end

  @doc "Check if a specific user is online."
  def online?(user_id) do
    cutoff = System.monotonic_time(:millisecond) - @stale_after_ms

    case :ets.lookup(@table, user_id) do
      [{^user_id, entry}] -> entry.last_seen > cutoff
      [] -> false
    end
  rescue
    ArgumentError -> false
  end

  @doc "List users currently viewing a specific page."
  def users_on_page(page) do
    cutoff = System.monotonic_time(:millisecond) - @stale_after_ms

    :ets.tab2list(@table)
    |> Enum.filter(fn {_id, entry} ->
      entry.last_seen > cutoff and entry.current_page == page
    end)
    |> Enum.map(fn {_id, entry} -> entry end)
  rescue
    ArgumentError -> []
  end

  # --- GenServer callbacks ---

  @impl true
  def init(:ok) do
    :ets.new(@table, [
      :set,
      :public,
      :named_table,
      read_concurrency: true,
      write_concurrency: true
    ])

    schedule_prune()
    {:ok, %{}}
  end

  @impl true
  def handle_info(:prune, state) do
    cutoff = System.monotonic_time(:millisecond) - @stale_after_ms

    :ets.tab2list(@table)
    |> Enum.each(fn {user_id, entry} ->
      if entry.last_seen <= cutoff do
        :ets.delete(@table, user_id)
      end
    end)

    schedule_prune()
    {:noreply, state}
  end

  defp schedule_prune do
    Process.send_after(self(), :prune, @prune_interval_ms)
  end
end
