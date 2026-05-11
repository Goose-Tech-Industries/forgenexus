defmodule ForgeNexus.Plugins.Nodes.Trigger.OnReportCreated do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  @impl true
  def execute(_config, _inputs, ctx) do
    td = ctx.trigger_data

    {:ok,
     %{
       report: Map.get(td, :report, Map.get(td, "report")),
       reporter: Map.get(td, :reporter, Map.get(td, "reporter")),
       target_type: Map.get(td, :target_type, Map.get(td, "target_type")),
       target_id: Map.get(td, :target_id, Map.get(td, "target_id")),
       reason: Map.get(td, :reason, Map.get(td, "reason"))
     }, ctx}
  end

  @impl true
  def validate_config(_config), do: :ok

  @impl true
  def schema do
    %{
      type: "trigger/on_report_created",
      category: "trigger",
      label: "On Report Created",
      description: "Triggers when a new report is submitted.",
      inputs: [],
      outputs: [
        %{name: "report", type: "map"},
        %{name: "reporter", type: "map"},
        %{name: "target_type", type: "string"},
        %{name: "target_id", type: "string"},
        %{name: "reason", type: "string"}
      ],
      config_fields: []
    }
  end
end
