defmodule ForgeNexus.Plugins.Nodes.Trigger.WebhookReceived do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  @impl true
  def execute(_config, _inputs, ctx) do
    td = ctx.trigger_data

    {:ok,
     %{
       method: Map.get(td, :method, Map.get(td, "method")),
       headers: Map.get(td, :headers, Map.get(td, "headers", %{})),
       body: Map.get(td, :body, Map.get(td, "body")),
       query: Map.get(td, :query, Map.get(td, "query", %{}))
     }, ctx}
  end

  @impl true
  def validate_config(_config), do: :ok

  @impl true
  def schema do
    %{
      type: "trigger/webhook_received",
      category: "trigger",
      label: "Webhook Received",
      description: "Triggers when an external webhook is received.",
      inputs: [],
      outputs: [
        %{name: "method", type: "string"},
        %{name: "headers", type: "map"},
        %{name: "body", type: "any"},
        %{name: "query", type: "map"}
      ],
      config_fields: []
    }
  end
end
