defmodule ForgeNexus.Plugins.Nodes.Collection.TradeCollectionItem do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox
  alias ForgeNexus.Collections

  @impl true
  def execute(_config, inputs, ctx) do
    Sandbox.check_db_limit!(ctx)

    from_user_id = Map.get(inputs, :from_user_id) || Map.get(inputs, "from_user_id")
    to_user_id = Map.get(inputs, :to_user_id) || Map.get(inputs, "to_user_id")

    collection_item_id =
      Map.get(inputs, :collection_item_id) || Map.get(inputs, "collection_item_id")

    case Collections.trade_item(from_user_id, to_user_id, collection_item_id) do
      {:ok, _} ->
        ctx = Sandbox.increment_db_ops(ctx)
        {:ok, %{success: true}, ctx}

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
      type: "collection/trade_collection_item",
      category: "collection",
      label: "Trade Collection Item",
      description: "Transfers a collection item from one user to another.",
      inputs: [
        %{name: "from_user_id", type: "string", required: true},
        %{name: "to_user_id", type: "string", required: true},
        %{name: "collection_item_id", type: "string", required: true}
      ],
      outputs: [
        %{name: "success", type: "boolean"}
      ],
      config_fields: []
    }
  end
end
