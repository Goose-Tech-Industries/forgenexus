defmodule ForgeNexus.Plugins.Nodes.Action.EmitCustomEvent do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  @impl true
  def execute(config, inputs, ctx) do
    event_name = Map.get(config, "event_name", "")
    payload = Map.get(inputs, :payload) || Map.get(inputs, "payload", %{})

    Phoenix.PubSub.broadcast(
      ForgeNexus.PubSub,
      "plugin:custom_event",
      {:custom_event, event_name, payload, ctx.flow_id}
    )

    {:ok, %{emitted: true, event_name: event_name}, ctx}
  end

  @impl true
  def validate_config(config) do
    if Map.get(config, "event_name", "") != "" do
      :ok
    else
      {:error, ["event_name is required"]}
    end
  end

  @impl true
  def schema do
    %{
      type: "action/emit_custom_event",
      category: "action",
      label: "Emit Custom Event",
      description: "Broadcasts a custom event that other flows can listen for.",
      inputs: [%{name: "payload", type: "map", required: false}],
      outputs: [
        %{name: "emitted", type: "boolean"},
        %{name: "event_name", type: "string"}
      ],
      config_fields: [
        %{name: "event_name", type: "string", default: "", description: "Event name to broadcast"}
      ]
    }
  end
end
