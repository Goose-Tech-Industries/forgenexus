defmodule ForgeNexus.Plugins.Nodes.Inventory.GiveItem do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox
  alias ForgeNexus.Inventory

  @impl true
  def execute(_config, inputs, ctx) do
    Sandbox.check_db_limit!(ctx)

    user_id = Map.get(inputs, :user_id) || Map.get(inputs, "user_id")
    item_template_id = Map.get(inputs, :item_template_id) || Map.get(inputs, "item_template_id")
    quantity = Map.get(inputs, :quantity) || Map.get(inputs, "quantity") || 1
    quantity = to_integer(quantity)

    case Inventory.give_item(user_id, item_template_id, quantity) do
      {:ok, item_or_items} ->
        ctx = Sandbox.increment_db_ops(ctx)
        {:ok, %{success: true, item: item_or_items, quantity: quantity}, ctx}

      {:error, reason} ->
        ctx = Sandbox.increment_db_ops(ctx)
        {:error, reason, ctx}
    end
  end

  defp to_integer(val) when is_integer(val), do: val
  defp to_integer(val) when is_float(val), do: trunc(val)

  defp to_integer(val) when is_binary(val) do
    case Integer.parse(val) do
      {n, _} -> n
      :error -> 1
    end
  end

  defp to_integer(_), do: 1

  @impl true
  def validate_config(_config), do: :ok

  @impl true
  def schema do
    %{
      type: "inventory/give_item",
      category: "inventory",
      label: "Give Item",
      description: "Adds an item to a user's inventory.",
      inputs: [
        %{name: "user_id", type: "string", required: true},
        %{name: "item_template_id", type: "string", required: true},
        %{name: "quantity", type: "number", required: false}
      ],
      outputs: [
        %{name: "success", type: "boolean"},
        %{name: "new_quantity", type: "number"}
      ],
      config_fields: []
    }
  end
end
