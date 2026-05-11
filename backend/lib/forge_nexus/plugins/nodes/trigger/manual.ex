defmodule ForgeNexus.Plugins.Nodes.Trigger.Manual do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  @impl true
  def execute(_config, _inputs, ctx) do
    td = ctx.trigger_data

    {:ok,
     %{
       triggered_by: ctx.triggered_by_id,
       params: Map.get(td, :params, Map.get(td, "params", %{}))
     }, ctx}
  end

  @impl true
  def validate_config(_config), do: :ok

  @impl true
  def schema do
    %{
      type: "trigger/manual",
      category: "trigger",
      label: "Manual Trigger",
      description: "Triggered manually by a user or admin.",
      inputs: [],
      outputs: [
        %{name: "triggered_by", type: "string"},
        %{name: "params", type: "map"}
      ],
      config_fields: []
    }
  end
end
