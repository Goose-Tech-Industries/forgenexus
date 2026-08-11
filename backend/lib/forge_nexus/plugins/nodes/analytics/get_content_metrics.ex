defmodule ForgeNexus.Plugins.Nodes.Analytics.GetContentMetrics do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox

  @impl true
  def execute(_config, inputs, ctx) do
    Sandbox.check_db_limit!(ctx)
    thread_id = Map.get(inputs, :thread_id) || Map.get(inputs, "thread_id")
    metrics = ForgeNexus.Forums.thread_engagement_metrics(thread_id)
    ctx = Sandbox.increment_db_ops(ctx)
    {:ok, metrics, ctx}
  end

  @impl true
  def validate_config(_config), do: :ok

  @impl true
  def schema do
    %{
      type: "analytics/get_content_metrics",
      category: "analytics",
      label: "Get Content Metrics",
      description:
        "Retrieves engagement metrics for a thread (views, replies, reactions, participants).",
      inputs: [%{name: "thread_id", type: "string", required: true}],
      outputs: [
        %{name: "views", type: "number"},
        %{name: "replies", type: "number"},
        %{name: "reactions", type: "number"},
        %{name: "unique_participants", type: "number"},
        %{name: "avg_response_time_hours", type: "number"}
      ],
      config_fields: []
    }
  end
end
