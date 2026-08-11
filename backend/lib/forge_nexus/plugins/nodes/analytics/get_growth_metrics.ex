defmodule ForgeNexus.Plugins.Nodes.Analytics.GetGrowthMetrics do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox

  @impl true
  def execute(config, _inputs, ctx) do
    Sandbox.check_db_limit!(ctx)
    period_days = Map.get(config, "period_days", 30) |> to_int()
    metrics = ForgeNexus.Forums.growth_metrics(period_days)
    ctx = Sandbox.increment_db_ops(ctx)
    {:ok, metrics, ctx}
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
  def validate_config(_config), do: :ok

  @impl true
  def schema do
    %{
      type: "analytics/get_growth_metrics",
      category: "analytics",
      label: "Get Growth Metrics",
      description:
        "Retrieves community growth metrics (new users, threads, posts, active users) for a period.",
      inputs: [],
      outputs: [
        %{name: "new_users", type: "number"},
        %{name: "new_threads", type: "number"},
        %{name: "new_posts", type: "number"},
        %{name: "active_users", type: "number"}
      ],
      config_fields: [
        %{
          name: "period_days",
          type: "number",
          default: 30,
          description: "Number of days to look back"
        }
      ]
    }
  end
end
