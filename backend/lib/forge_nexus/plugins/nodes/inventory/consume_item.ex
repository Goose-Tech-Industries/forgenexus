defmodule ForgeNexus.Plugins.Nodes.Inventory.ConsumeItem do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox
  alias ForgeNexus.Inventory

  @impl true
  def execute(_config, inputs, ctx) do
    Sandbox.check_db_limit!(ctx)

    user_id = Map.get(inputs, :user_id) || Map.get(inputs, "user_id")
    inventory_id = Map.get(inputs, :inventory_id) || Map.get(inputs, "inventory_id")

    case Inventory.consume_item(user_id, inventory_id) do
      {:ok, item_template} ->
        ctx = Sandbox.increment_db_ops(ctx)
        {:ok, %{success: true, item_template: item_template}, ctx}

      {:error, reason} ->
        ctx = Sandbox.increment_db_ops(ctx)
        {:error, reason, ctx}
    end
  end

  @impl true
  def validate_config(_config), do: :ok

  @impl true
  def schema do
    %{
      type: "inventory/consume_item",
      category: "inventory",
      label: "Consume Item",
      description:
        "Consumes an item, removing it and returning its template for effect processing.",
      inputs: [
        %{name: "user_id", type: "string", required: true},
        %{name: "inventory_id", type: "string", required: true}
      ],
      outputs: [
        %{name: "success", type: "boolean"},
        %{name: "item_template", type: "map"}
      ],
      config_fields: []
    }
  end
end
