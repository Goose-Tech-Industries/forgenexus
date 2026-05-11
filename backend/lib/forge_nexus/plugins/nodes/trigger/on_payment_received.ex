defmodule ForgeNexus.Plugins.Nodes.Trigger.OnPaymentReceived do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  @impl true
  def execute(_config, _inputs, ctx) do
    td = ctx.trigger_data

    {:ok,
     %{
       user: Map.get(td, :user, Map.get(td, "user")),
       amount: Map.get(td, :amount, Map.get(td, "amount")),
       currency: Map.get(td, :currency, Map.get(td, "currency")),
       payment_type: Map.get(td, :payment_type, Map.get(td, "payment_type")),
       metadata: Map.get(td, :metadata, Map.get(td, "metadata"))
     }, ctx}
  end

  @impl true
  def validate_config(_config), do: :ok

  @impl true
  def schema do
    %{
      type: "trigger/on_payment_received",
      category: "trigger",
      label: "On Payment Received",
      description: "Triggers when a payment is received.",
      inputs: [],
      outputs: [
        %{name: "user", type: "map"},
        %{name: "amount", type: "number"},
        %{name: "currency", type: "string"},
        %{name: "payment_type", type: "string"},
        %{name: "metadata", type: "map"}
      ],
      config_fields: []
    }
  end
end
