defmodule ForgeNexus.Plugins.Nodes.Inventory.TransferItem do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox
  alias ForgeNexus.Inventory

  @impl true
  def execute(_config, inputs, ctx) do
    Sandbox.check_db_limit!(ctx)

    from_user_id = Map.get(inputs, :from_user_id) || Map.get(inputs, "from_user_id")
    to_user_id = Map.get(inputs, :to_user_id) || Map.get(inputs, "to_user_id")
    item_template_id = Map.get(inputs, :item_template_id) || Map.get(inputs, "item_template_id")
    quantity = Map.get(inputs, :quantity) || Map.get(inputs, "quantity") || 1
    quantity = to_integer(quantity)

    case Inventory.transfer_item(from_user_id, to_user_id, item_template_id, quantity) do
      {:ok, _} ->
        ctx = Sandbox.increment_db_ops(ctx)
        {:ok, %{success: true}, ctx}

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
      type: "inventory/transfer_item",
      category: "inventory",
      label: "Transfer Item",
      description: "Transfers an item from one user to another.",
      inputs: [
        %{name: "from_user_id", type: "string", required: true},
        %{name: "to_user_id", type: "string", required: true},
        %{name: "item_template_id", type: "string", required: true},
        %{name: "quantity", type: "number", required: true}
      ],
      outputs: [
        %{name: "success", type: "boolean"}
      ],
      config_fields: []
    }
  end
end
