defmodule ForgeNexus.Plugins.Scheduler do
  @moduledoc """
  Oban worker that runs every minute to check for scheduled flows
  whose cron expressions match the current time.
  """

  use Oban.Worker, queue: :plugins, max_attempts: 1

  require Logger

  alias ForgeNexus.Plugins
  alias ForgeNexus.Plugins.Engine.Executor

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    now = DateTime.utc_now()
    flows = Plugins.get_active_flows_for_trigger("scheduled")

    for flow <- flows do
      cron = Map.get(flow.trigger_config, "cron_expression", "")

      if cron_matches?(cron, now) do
        Logger.info("[Plugins.Scheduler] Triggering scheduled flow #{flow.id} (#{flow.name})")

        Task.Supervisor.start_child(ForgeNexus.PluginTaskSupervisor, fn ->
          try do
            Executor.execute_flow(flow.id, %{timestamp: now, flow_id: flow.id}, nil)
          rescue
            e ->
              Logger.error("[Plugins.Scheduler] Flow #{flow.id} failed: #{inspect(e)}")
          end
        end)
      end
    end

    :ok
  end

  @doc """
  Simple cron matcher supporting: minute hour day_of_month month day_of_week
  Supports * (any) and specific numbers. Does not support ranges or steps (yet).
  """
  def cron_matches?(cron_expression, datetime) do
    parts = String.split(String.trim(cron_expression))

    if length(parts) != 5 do
      false
    else
      [minute, hour, day, month, weekday] = parts

      matches_field?(minute, datetime.minute) and
        matches_field?(hour, datetime.hour) and
        matches_field?(day, datetime.day) and
        matches_field?(month, datetime.month) and
        matches_field?(weekday, Date.day_of_week(datetime) |> rem(7))
    end
  end

  defp matches_field?("*", _value), do: true

  defp matches_field?(field, value) do
    case Integer.parse(field) do
      {n, ""} -> n == value
      _ -> false
    end
  end
end
