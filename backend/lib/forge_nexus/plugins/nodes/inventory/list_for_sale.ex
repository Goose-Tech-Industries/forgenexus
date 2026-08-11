defmodule ForgeNexus.Plugins.Nodes.Inventory.ListForSale do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox

  @impl true
  def execute(config, inputs, ctx) do
    Sandbox.check_db_limit!(ctx)
    user_id = Map.get(inputs, :user_id) || Map.get(inputs, "user_id")
    inventory_id = Map.get(inputs, :inventory_id) || Map.get(inputs, "inventory_id")
    price = Map.get(inputs, :price) || Map.get(inputs, "price")
    currency_slug = Map.get(config, "currency_slug", "points")

    flow_data = Map.get(ctx, :flow_data, %{})
    listings = Map.get(flow_data, "marketplace_listings", %{})
    listing_id = Ecto.UUID.generate()

    listing = %{
      "id" => listing_id,
      "seller_id" => user_id,
      "inventory_id" => inventory_id,
      "price" => price,
      "currency_slug" => currency_slug,
      "status" => "active",
      "listed_at" => DateTime.utc_now() |> DateTime.to_iso8601()
    }

    listings = Map.put(listings, listing_id, listing)
    flow_data = Map.put(flow_data, "marketplace_listings", listings)
    ctx = Map.put(ctx, :flow_data, flow_data)
    ctx = Sandbox.increment_db_ops(ctx)

    {:ok, %{listing_id: listing_id, success: true}, ctx}
  end

  @impl true
  def validate_config(_config), do: :ok

  @impl true
  def schema do
    %{
      type: "inventory/list_for_sale",
      category: "inventory",
      label: "List for Sale",
      description: "Lists an inventory item for sale on the marketplace (in-flow ledger).",
      inputs: [
        %{name: "user_id", type: "string", required: true},
        %{name: "inventory_id", type: "string", required: true},
        %{name: "price", type: "number", required: true}
      ],
      outputs: [
        %{name: "listing_id", type: "string"},
        %{name: "success", type: "boolean"}
      ],
      config_fields: [
        %{
          name: "currency_slug",
          type: "string",
          default: "points",
          description: "Currency for the listing price"
        }
      ]
    }
  end
end
