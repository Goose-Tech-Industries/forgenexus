defmodule ForgeNexus.Plugins.Nodes.Economy.SetPrice do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox

  @impl true
  def execute(config, inputs, ctx) do
    Sandbox.check_db_limit!(ctx)
    item_id = Map.get(inputs, :item_id) || Map.get(inputs, "item_id")
    price = Map.get(inputs, :price) || Map.get(inputs, "price")
    currency_slug = Map.get(config, "currency_slug", "points")

    flow_data = Map.get(ctx, :flow_data, %{})
    prices = Map.get(flow_data, "item_prices", %{})
    prices = Map.put(prices, item_id, %{"price" => price, "currency" => currency_slug})
    flow_data = Map.put(flow_data, "item_prices", prices)
    ctx = Map.put(ctx, :flow_data, flow_data)
    ctx = Sandbox.increment_db_ops(ctx)

    {:ok, %{success: true}, ctx}
  end

  @impl true
  def validate_config(_config), do: :ok

  @impl true
  def schema do
    %{
      type: "economy/set_price",
      category: "economy",
      label: "Set Price",
      description: "Sets a price for an item in a given currency (in-flow price ledger).",
      inputs: [
        %{name: "item_id", type: "string", required: true},
        %{name: "price", type: "number", required: true}
      ],
      outputs: [%{name: "success", type: "boolean"}],
      config_fields: [
        %{name: "currency_slug", type: "string", default: "points", description: "Currency identifier slug"}
      ]
    }
  end
end
