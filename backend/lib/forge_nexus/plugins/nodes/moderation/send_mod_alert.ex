defmodule ForgeNexus.Plugins.Nodes.Moderation.SendModAlert do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  @impl true
  def execute(_config, inputs, ctx) do
    title = Map.get(inputs, :title) || Map.get(inputs, "title", "")
    description = Map.get(inputs, :description) || Map.get(inputs, "description", "")
    severity = Map.get(inputs, :severity) || Map.get(inputs, "severity", "info")
    metadata = Map.get(inputs, :metadata) || Map.get(inputs, "metadata", %{})

    severity = if severity in ~w(info warning critical), do: severity, else: "info"

    {:ok, _payload} = ForgeNexus.Moderation.send_mod_alert(title, description, severity, metadata)
    {:ok, %{success: true}, ctx}
  end

  @impl true
  def validate_config(_config), do: :ok

  @impl true
  def schema do
    %{
      type: "moderation/send_mod_alert",
      category: "moderation",
      label: "Send Mod Alert",
      description: "Broadcasts an alert to the moderator dashboard via PubSub.",
      inputs: [
        %{name: "title", type: "string", required: true},
        %{name: "description", type: "string", required: false},
        %{name: "severity", type: "string", required: false},
        %{name: "metadata", type: "map", required: false}
      ],
      outputs: [%{name: "success", type: "boolean"}],
      config_fields: []
    }
  end
end
