defmodule ForgeNexus.Telemetry.SlowQueryLogger do
  @moduledoc """
  Logs database queries that exceed a threshold.
  Attaches to Ecto telemetry events on application start.

  In dev: logs queries > 200ms
  In prod: logs queries > 100ms as warnings
  """
  require Logger

  @threshold_ms Application.compile_env(:forge_nexus, :slow_query_threshold_ms, 100)

  def setup do
    :telemetry.attach(
      "forge-nexus-slow-queries",
      [:forge_nexus, :repo, :query],
      &__MODULE__.handle_event/4,
      %{}
    )
  end

  def handle_event([:forge_nexus, :repo, :query], measurements, metadata, _config) do
    # Total time includes queue + query + decode
    total_ms = System.convert_time_unit(measurements.total_time || 0, :native, :millisecond)
    query_ms = System.convert_time_unit(measurements.query_time || 0, :native, :millisecond)
    queue_ms = System.convert_time_unit(measurements.queue_time || 0, :native, :millisecond)

    threshold = @threshold_ms

    if total_ms > threshold do
      source = metadata[:source] || "unknown"
      query = String.slice(metadata.query || "", 0, 500)
      params = inspect(metadata.params || [], limit: 10, printable_limit: 100)

      Logger.warning(
        "[SlowQuery] #{total_ms}ms (query=#{query_ms}ms queue=#{queue_ms}ms) " <>
          "source=#{source} query=#{query} params=#{params}"
      )
    end
  rescue
    # Never crash on telemetry — just log and move on
    _ -> :ok
  end
end
