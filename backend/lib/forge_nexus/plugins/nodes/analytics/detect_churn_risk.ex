defmodule ForgeNexus.Plugins.Nodes.Analytics.DetectChurnRisk do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox

  @impl true
  def execute(config, _inputs, ctx) do
    Sandbox.check_db_limit!(ctx)
    inactive_days = Map.get(config, "inactive_days", 14) |> to_int()
    min_previous_activity = Map.get(config, "min_previous_activity", 5) |> to_int()
    at_risk_users = ForgeNexus.Forums.detect_churn_risk_users(inactive_days, min_previous_activity)
    ctx = Sandbox.increment_db_ops(ctx)
    {:ok, %{at_risk_users: at_risk_users}, ctx}
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
      type: "analytics/detect_churn_risk",
      category: "analytics",
      label: "Detect Churn Risk",
      description: "Identifies previously active users who are at risk of churning based on inactivity.",
      inputs: [],
      outputs: [%{name: "at_risk_users", type: "list"}],
      config_fields: [
        %{name: "inactive_days", type: "number", default: 14, description: "Days of inactivity to flag a user"},
        %{name: "min_previous_activity", type: "number", default: 5, description: "Minimum previous posts to qualify as formerly active"}
      ]
    }
  end
end
