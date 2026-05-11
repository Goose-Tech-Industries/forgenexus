defmodule ForgeNexus.Plugins.Nodes.Trigger.Scheduled do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  @impl true
  def execute(_config, _inputs, ctx) do
    {:ok, %{timestamp: DateTime.utc_now(), flow_id: ctx.flow_id}, ctx}
  end

  @impl true
  def validate_config(_config), do: :ok

  @impl true
  def schema do
    %{
      type: "trigger/scheduled",
      category: "trigger",
      label: "Scheduled",
      description: "Triggers on a schedule (cron-like).",
      inputs: [],
      outputs: [
        %{name: "timestamp", type: "datetime"},
        %{name: "flow_id", type: "string"}
      ],
      config_fields: [
        %{name: "cron", type: "string", default: "0 * * * *", description: "Cron expression"}
      ]
    }
  end
end
