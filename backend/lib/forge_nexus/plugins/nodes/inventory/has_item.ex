defmodule ForgeNexus.Plugins.Nodes.Inventory.HasItem do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox
  alias ForgeNexus.Inventory

  @impl true
  def execute(_config, inputs, ctx) do
    Sandbox.check_db_limit!(ctx)

    user_id = Map.get(inputs, :user_id) || Map.get(inputs, "user_id")
    item_template_id = Map.get(inputs, :item_template_id) || Map.get(inputs, "item_template_id")

    result = Inventory.has_item?(user_id, item_template_id)
    ctx = Sandbox.increment_db_ops(ctx)
    port = if result, do: "yes", else: "no"
    {:branch, port, %{has_item: result, quantity: if(result, do: 1, else: 0)}, ctx}
  end

  @impl true
  def validate_config(_config), do: :ok

  @impl true
  def schema do
    %{
      type: "inventory/has_item",
      category: "inventory",
      label: "Has Item?",
      description: "Branches based on whether a user has a minimum quantity of an item.",
      inputs: [
        %{name: "user_id", type: "string", required: true},
        %{name: "item_template_id", type: "string", required: true}
      ],
      outputs: [
        %{name: "yes", type: "number"},
        %{name: "no", type: "number"}
      ],
      config_fields: [
        %{name: "min_quantity", type: "number", default: 1, description: "Minimum quantity required"}
      ]
    }
  end
end
