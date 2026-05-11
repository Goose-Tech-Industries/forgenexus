defmodule ForgeNexus.Plugins.Nodes.Analytics.GetEngagementScore do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox

  @impl true
  def execute(config, inputs, ctx) do
    Sandbox.check_db_limit!(ctx)
    user_id = Map.get(inputs, :user_id) || Map.get(inputs, "user_id")
    period_days = Map.get(config, "period_days", 30) |> to_int()

    result = ForgeNexus.Forums.engagement_score(user_id, period_days)
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
  def validate_config(_config), do: :ok

  @impl true
  def schema do
    %{
      type: "analytics/get_engagement_score",
      category: "analytics",
      label: "Get Engagement Score",
      description: "Calculates a composite engagement score (0-100) for a user with breakdown.",
      inputs: [%{name: "user_id", type: "string", required: true}],
      outputs: [%{name: "score", type: "number"}, %{name: "breakdown", type: "map"}],
      config_fields: [%{name: "period_days", type: "number", default: 30, description: "Number of days to look back"}]
    }
  end
end
