defmodule ForgeNexus.Plugins.Nodes.Inventory.ItemDurability do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox

  @impl true
  def execute(_config, inputs, ctx) do
    Sandbox.check_db_limit!(ctx)
    inventory_id = Map.get(inputs, :inventory_id) || Map.get(inputs, "inventory_id")
    wear_amount_in = Map.get(inputs, :wear_amount) || Map.get(inputs, "wear_amount", 1)
    wear_amount = if is_integer(wear_amount_in), do: wear_amount_in, else: trunc(wear_amount_in)

    flow_data = Map.get(ctx, :flow_data, %{})
    durability_map = Map.get(flow_data, "item_durability", %{})
    current = Map.get(durability_map, inventory_id, 100)
    new_dur = max(0, current - wear_amount)
    durability_map = Map.put(durability_map, inventory_id, new_dur)
    flow_data = Map.put(flow_data, "item_durability", durability_map)
    ctx = Map.put(ctx, :flow_data, flow_data)
    ctx = Sandbox.increment_db_ops(ctx)

    if new_dur > 0 do
      {:branch, "intact", %{durability: new_dur, max_durability: 100}, ctx}
    else
      {:branch, "broken", %{durability: 0, max_durability: 100}, ctx}
    end
  end

  @impl true
  def validate_config(_config), do: :ok

  @impl true
  def schema do
    %{
      type: "inventory/item_durability",
      category: "inventory",
      label: "Item Durability",
      description:
        "Applies wear to an item and branches based on whether it is intact or broken.",
      inputs: [
        %{name: "inventory_id", type: "string", required: true},
        %{name: "wear_amount", type: "number", required: false}
      ],
      outputs: [
        %{
          name: "intact",
          type: "branch",
          fields: [
            %{name: "durability", type: "number"},
            %{name: "max_durability", type: "number"}
          ]
        },
        %{
          name: "broken",
          type: "branch",
          fields: [
            %{name: "durability", type: "number"},
            %{name: "max_durability", type: "number"}
          ]
        }
      ],
      config_fields: []
    }
  end
end
