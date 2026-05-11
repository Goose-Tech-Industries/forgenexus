defmodule ForgeNexus.Plugins.Nodes.Analytics.GetUserActivity do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox

  @impl true
  def execute(config, inputs, ctx) do
    Sandbox.check_db_limit!(ctx)
    user_id = Map.get(inputs, :user_id) || Map.get(inputs, "user_id")
    period_days = Map.get(config, "period_days", 30) |> to_int()

    metrics = ForgeNexus.Forums.user_activity_metrics(user_id, period_days)
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
      type: "analytics/get_user_activity",
      category: "analytics",
      label: "Get User Activity",
      description: "Retrieves activity metrics for a user over a specified period.",
      inputs: [%{name: "user_id", type: "string", required: true}],
      outputs: [
        %{name: "posts", type: "number"},
        %{name: "threads", type: "number"},
        %{name: "reactions_given", type: "number"},
        %{name: "reactions_received", type: "number"},
        %{name: "logins", type: "number"}
      ],
      config_fields: [%{name: "period_days", type: "number", default: 30, description: "Number of days to look back"}]
    }
  end
end
