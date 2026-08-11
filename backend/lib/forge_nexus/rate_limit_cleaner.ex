defmodule ForgeNexus.RateLimitCleaner do
  @moduledoc """
  Periodically cleans up expired rate limit entries from ETS.
  Also initializes the ETS table on startup.
  """
  use GenServer

  @table :forge_nexus_rate_limits
  @cleanup_interval :timer.minutes(2)

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @impl true
  def init(:ok) do
    # Create ETS table if it doesn't exist
    if :ets.whereis(@table) == :undefined do
      :ets.new(@table, [
        :set,
        :public,
        :named_table,
        read_concurrency: true,
        write_concurrency: true
      ])
    end

    schedule_cleanup()
    {:ok, %{}}
  end

  @impl true
  def handle_info(:cleanup, state) do
    ForgeNexusWeb.Plugs.RateLimit.cleanup_expired()
    schedule_cleanup()
    {:noreply, state}
  end

  defp schedule_cleanup do
    Process.send_after(self(), :cleanup, @cleanup_interval)
  end
end
