defmodule ForgeNexus.Plugins.Nodes.Trigger.OnCustomEvent do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  @impl true
  def execute(_config, _inputs, ctx) do
    td = ctx.trigger_data

    {:ok,
     %{
       event_name: Map.get(td, :event_name, Map.get(td, "event_name")),
       payload: Map.get(td, :payload, Map.get(td, "payload", %{})),
       emitter_flow_id: Map.get(td, :emitter_flow_id, Map.get(td, "emitter_flow_id"))
     }, ctx}
  end

  @impl true
  def validate_config(_config), do: :ok

  @impl true
  def schema do
    %{
      type: "trigger/on_custom_event",
      category: "trigger",
      label: "On Custom Event",
      description: "Triggers when a custom event is emitted by another flow.",
      inputs: [],
      outputs: [
        %{name: "event_name", type: "string"},
        %{name: "payload", type: "map"},
        %{name: "emitter_flow_id", type: "string"}
      ],
      config_fields: [
        %{name: "event_name", type: "string", default: "", description: "Event name to listen for"}
      ]
    }
  end
end
