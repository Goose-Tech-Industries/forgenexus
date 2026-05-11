defmodule ForgeNexus.Plugins.Nodes.Analytics.DetectTrending do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox

  @impl true
  def execute(config, _inputs, ctx) do
    Sandbox.check_db_limit!(ctx)
    period_hours = Map.get(config, "period_hours", 24) |> to_int()
    limit = Map.get(config, "limit", 10) |> to_int()
    trending_threads = ForgeNexus.Forums.detect_trending_threads(period_hours, limit)
    ctx = Sandbox.increment_db_ops(ctx)
    {:ok, %{trending_threads: trending_threads}, ctx}
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
      type: "analytics/detect_trending",
      category: "analytics",
      label: "Detect Trending",
      description: "Identifies trending threads based on recent engagement velocity.",
      inputs: [],
      outputs: [%{name: "trending_threads", type: "list"}],
      config_fields: [
        %{name: "period_hours", type: "number", default: 24, description: "Hours to look back for trending calculation"},
        %{name: "limit", type: "number", default: 10, description: "Maximum number of trending threads to return"}
      ]
    }
  end
end
