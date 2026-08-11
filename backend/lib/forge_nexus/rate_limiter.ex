defmodule ForgeNexus.RateLimiter do
  @moduledoc """
  ETS-based rate limiter for thread and post creation.
  Tracks actions per user and enforces configurable limits.
  """

  use GenServer

  @table :forge_nexus_rate_limiter

  # {action, max_count, window_seconds}
  @limits %{
    create_thread: {5, 600},
    create_post: {20, 600}
  }

  # --- Client API ---

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @doc """
  Checks if the user has exceeded the rate limit for the given action.
  Returns `:ok` or `{:error, :rate_limited}`.
  """
  def check_rate(user_id, action) do
    {max_count, window_seconds} = Map.fetch!(@limits, action)
    now = System.system_time(:second)
    cutoff = now - window_seconds

    key = {user_id, action}

    entries =
      case :ets.lookup(@table, key) do
        [{^key, timestamps}] -> timestamps
        [] -> []
      end

    # Count entries within the window
    recent = Enum.filter(entries, fn ts -> ts > cutoff end)

    if length(recent) >= max_count do
      {:error, :rate_limited}
    else
      :ok
    end
  end

  @doc """
  Records an action for the given user.
  """
  def record_action(user_id, action) do
    {_max_count, window_seconds} = Map.fetch!(@limits, action)
    now = System.system_time(:second)
    cutoff = now - window_seconds

    key = {user_id, action}

    existing =
      case :ets.lookup(@table, key) do
        [{^key, timestamps}] -> timestamps
        [] -> []
      end

    # Prune old entries and add new one
    updated = [now | Enum.filter(existing, fn ts -> ts > cutoff end)]
    :ets.insert(@table, {key, updated})

    :ok
  end

  # --- Server Callbacks ---

  @impl true
  def init(_) do
    table = :ets.new(@table, [:named_table, :public, :set])
    # Schedule periodic cleanup every 5 minutes
    Process.send_after(self(), :cleanup, 300_000)
    {:ok, %{table: table}}
  end

  @impl true
  def handle_info(:cleanup, state) do
    now = System.system_time(:second)
    # Max window is 600 seconds, so prune anything older
    cutoff = now - 600

    @table
    |> :ets.tab2list()
    |> Enum.each(fn {key, timestamps} ->
      pruned = Enum.filter(timestamps, fn ts -> ts > cutoff end)

      if pruned == [] do
        :ets.delete(@table, key)
      else
        :ets.insert(@table, {key, pruned})
      end
    end)

    Process.send_after(self(), :cleanup, 300_000)
    {:noreply, state}
  end
end
