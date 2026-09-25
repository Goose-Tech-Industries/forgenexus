defmodule ForgeNexus.Inventory.InventorySchemasTest do
  use ForgeNexus.DataCase, async: true

  alias ForgeNexus.Inventory.{
    CraftingRecipe,
    InventoryItem,
    ItemTemplate
  }

  describe "CraftingRecipe" do
    @rid Ecto.UUID.generate()

    test "valid changeset" do
      cs =
        CraftingRecipe.changeset(%CraftingRecipe{}, %{
          name: "Healing Potion",
          description: "Restores health",
          success_rate: 0.9,
          ingredients: [%{"item_template_id" => Ecto.UUID.generate(), "quantity" => 2}],
          result_item_id: @rid,
          result_quantity: 1,
          is_active: true
        })

      assert cs.valid?
      assert get_field(cs, :name) == "Healing Potion"
      assert get_field(cs, :success_rate) == 0.9
    end

    test "validates required fields and success_rate range" do
      cs = CraftingRecipe.changeset(%CraftingRecipe{}, %{ingredients: nil})
      refute cs.valid?
      assert "can't be blank" in errors_on(cs).name
      assert "can't be blank" in errors_on(cs).ingredients
      assert "can't be blank" in errors_on(cs).result_item_id

      bad_rate_cs =
        CraftingRecipe.changeset(%CraftingRecipe{}, %{
          name: "Bad Recipe",
          ingredients: [%{}],
          result_item_id: @rid,
          success_rate: 0.0
        })

      refute bad_rate_cs.valid?
      assert "must be greater than 0.0" in errors_on(bad_rate_cs).success_rate

      over_rate_cs =
        CraftingRecipe.changeset(%CraftingRecipe{}, %{
          name: "Bad Recipe",
          ingredients: [%{}],
          result_item_id: @rid,
          success_rate: 1.5
        })

      refute over_rate_cs.valid?
      assert "must be less than or equal to 1.0" in errors_on(over_rate_cs).success_rate
    end
  end

  describe "InventoryItem" do
    @uid Ecto.UUID.generate()
    @tid Ecto.UUID.generate()

    test "valid changeset" do
      cs =
        InventoryItem.changeset(%InventoryItem{}, %{
          user_id: @uid,
          item_template_id: @tid,
          quantity: 5,
          is_equipped: true,
          metadata: %{"durability" => 100}
        })

      assert cs.valid?
      assert get_field(cs, :quantity) == 5
      assert get_field(cs, :is_equipped) == true
    end

    test "validates required fields and quantity > 0" do
      cs = InventoryItem.changeset(%InventoryItem{}, %{quantity: nil})
      refute cs.valid?
      assert "can't be blank" in errors_on(cs).user_id
      assert "can't be blank" in errors_on(cs).item_template_id
      assert "can't be blank" in errors_on(cs).quantity

      zero_cs =
        InventoryItem.changeset(%InventoryItem{}, %{
          user_id: @uid,
          item_template_id: @tid,
          quantity: 0
        })

      refute zero_cs.valid?
      assert "must be greater than 0" in errors_on(zero_cs).quantity
    end
  end

  describe "ItemTemplate" do
    test "valid changeset with rarity inclusions" do
      for rarity <- ~w(common uncommon rare epic legendary) do
        cs =
          ItemTemplate.changeset(%ItemTemplate{}, %{
            name: "Sword of #{rarity}",
            slug: "sword-of-#{rarity}",
            rarity: rarity,
            category: "weapons"
          })

        assert cs.valid?
        assert get_field(cs, :rarity) == rarity
      end
    end

    test "validates required fields and invalid rarity" do
      cs = ItemTemplate.changeset(%ItemTemplate{}, %{})
      refute cs.valid?
      assert "can't be blank" in errors_on(cs).name
      assert "can't be blank" in errors_on(cs).slug

      bad_rarity_cs =
        ItemTemplate.changeset(%ItemTemplate{}, %{
          name: "Godly Blade",
          slug: "godly-blade",
          rarity: "mythic"
        })

      refute bad_rarity_cs.valid?
      assert "is invalid" in errors_on(bad_rarity_cs).rarity
    end
  end
end
