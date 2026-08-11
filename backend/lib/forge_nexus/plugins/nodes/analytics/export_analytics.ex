defmodule ForgeNexus.Plugins.Nodes.Analytics.ExportAnalytics do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox

  @impl true
  def execute(config, _inputs, ctx) do
    Sandbox.check_db_limit!(ctx)
    metrics_raw = Map.get(config, "metrics", "")
    period_days = Map.get(config, "period_days", 30) |> to_int()
    format = Map.get(config, "format", "json")

    metrics =
      metrics_raw |> String.split(",") |> Enum.map(&String.trim/1) |> Enum.reject(&(&1 == ""))

    rows =
      Enum.map(metrics, fn m ->
        %{metric: m, value: aggregate_metric(m, period_days)}
      end)

    {data, row_count} =
      case format do
        "csv" ->
          header = "metric,value"
          body = Enum.map_join(rows, "\n", fn r -> "#{r.metric},#{r.value}" end)
          {"#{header}\n#{body}\n", length(rows)}

        _ ->
          {Jason.encode!(%{metrics: metrics, period_days: period_days, rows: rows}), length(rows)}
      end

    ctx = Sandbox.increment_db_ops(ctx)
    {:ok, %{data: data, row_count: row_count}, ctx}
  end

  defp aggregate_metric(metric, period_days) do
    %{current: current} =
      ForgeNexus.Forums.compare_metric_periods(metric, period_days, "previous_period")

    current
  end

  defp to_int(v) when is_integer(v), do: v
  defp to_int(v) when is_float(v), do: trunc(v)

  defp to_int(v) when is_binary(v) do
    case Integer.parse(v) do
      {n, _} -> n
      _ -> 0
    end
  end

  defp to_int(_), do: 0

  @impl true
  def validate_config(config) do
    errors =
      []
      |> then(fn e ->
        case Map.get(config, "metrics") do
          nil -> ["metrics is required" | e]
          "" -> ["metrics cannot be empty" | e]
          _ -> e
        end
      end)
      |> then(fn e ->
        if Map.get(config, "format", "json") in ~w(json csv),
          do: e,
          else: ["format must be json or csv" | e]
      end)

    if errors == [], do: :ok, else: {:error, errors}
  end

  @impl true
  def schema do
    %{
      type: "analytics/export_analytics",
      category: "analytics",
      label: "Export Analytics",
      description: "Exports analytics data in JSON or CSV format.",
      inputs: [],
      outputs: [%{name: "data", type: "string"}, %{name: "row_count", type: "number"}],
      config_fields: [
        %{
          name: "metrics",
          type: "string",
          default: "",
          description: "Comma-separated metric names to export"
        },
        %{
          name: "period_days",
          type: "number",
          default: 30,
          description: "Number of days of data to export"
        },
        %{
          name: "format",
          type: "select",
          options: ~w(json csv),
          default: "json",
          description: "Export format"
        }
      ]
    }
  end
end
