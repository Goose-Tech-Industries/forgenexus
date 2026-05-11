defmodule ForgeNexus.Plugins.Nodes.Inventory.GetInventory do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox
  alias ForgeNexus.Inventory

  @impl true
  def execute(_config, inputs, ctx) do
    Sandbox.check_db_limit!(ctx)

    user_id = Map.get(inputs, :user_id) || Map.get(inputs, "user_id")

    items = Inventory.get_inventory(user_id)
    ctx = Sandbox.increment_db_ops(ctx)
    {:ok, %{items: items, total_count: length(items)}, ctx}
  end

  @impl true
  def validate_config(_config), do: :ok

  @impl true
  def schema do
    %{
      type: "inventory/get_inventory",
      category: "inventory",
      label: "Get Inventory",
      description: "Retrieves a user's inventory, optionally filtered by category.",
      inputs: [
        %{name: "user_id", type: "string", required: true}
      ],
      outputs: [
        %{name: "items", type: "list"},
        %{name: "total_count", type: "number"}
      ],
      config_fields: [
        %{name: "category_filter", type: "string", default: "", description: "Optional category to filter by"}
      ]
    }
  end
end
