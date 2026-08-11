defmodule ForgeNexus.Plugins.Nodes.Analytics.ComparePeriods do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox

  @impl true
  def execute(config, _inputs, ctx) do
    Sandbox.check_db_limit!(ctx)
    metric = Map.get(config, "metric", "posts")
    period_days = Map.get(config, "period_days", 30) |> to_int()
    compare_to = Map.get(config, "compare_to", "previous_period")

    result = ForgeNexus.Forums.compare_metric_periods(metric, period_days, compare_to)
    ctx = Sandbox.increment_db_ops(ctx)
    {:ok, result, ctx}
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
        if Map.get(config, "metric", "posts") in ~w(users posts threads active_users),
          do: e,
          else: ["metric must be users, posts, threads, or active_users" | e]
      end)
      |> then(fn e ->
        if Map.get(config, "compare_to", "previous_period") in ~w(previous_period same_period_last_month),
          do: e,
          else: ["compare_to must be previous_period or same_period_last_month" | e]
      end)

    if errors == [], do: :ok, else: {:error, errors}
  end

  @impl true
  def schema do
    %{
      type: "analytics/compare_periods",
      category: "analytics",
      label: "Compare Periods",
      description:
        "Compares a metric between the current period and a previous period, showing trend direction.",
      inputs: [],
      outputs: [
        %{name: "current", type: "number"},
        %{name: "previous", type: "number"},
        %{name: "change_percent", type: "number"},
        %{name: "trend", type: "string"}
      ],
      config_fields: [
        %{
          name: "metric",
          type: "select",
          options: ~w(users posts threads active_users),
          default: "posts",
          description: "Metric to compare"
        },
        %{
          name: "period_days",
          type: "number",
          default: 30,
          description: "Number of days in each period"
        },
        %{
          name: "compare_to",
          type: "select",
          options: ~w(previous_period same_period_last_month),
          default: "previous_period",
          description: "What to compare against"
        }
      ]
    }
  end
end
