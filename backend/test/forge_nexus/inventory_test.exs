defmodule ForgeNexus.InventoryTest do
  use ForgeNexus.DataCase, async: true

  alias ForgeNexus.Inventory
  alias ForgeNexus.Inventory.{ItemTemplate, InventoryItem, CraftingRecipe}
  alias ForgeNexus.Accounts

  defp create_user do
    unique = System.unique_integer([:positive])

    {:ok, user} =
      Accounts.register_user(%{
        username: "inv_u_#{unique}",
        email: "inv_u_#{unique}@example.com",
        password: "ValidPassword123!@#"
      })

    user
  end

  defp item_template_attrs(attrs \\ %{}) do
    unique = System.unique_integer([:positive])

    Enum.into(attrs, %{
      name: "Iron Sword #{unique}",
      slug: "iron-sword-#{unique}",
      description: "A sharp blade",
      category: "weapon",
      rarity: "common",
      is_stackable: true,
      max_stack: 10,
      is_equippable: true,
      is_consumable: false
    })
  end

  describe "item templates" do
    test "create, get, get_by_slug, list" do
      attrs = item_template_attrs()
      assert {:ok, %ItemTemplate{} = template} = Inventory.create_item_template(attrs)
      assert template.name == attrs.name

      assert %ItemTemplate{} = Inventory.get_item_template!(template.id)
      assert %ItemTemplate{} = Inventory.get_item_template_by_slug(template.slug)
      assert is_nil(Inventory.get_item_template_by_slug("nonexistent-slug-xyz"))

      templates = Inventory.list_item_templates()
      assert Enum.any?(templates, &(&1.id == template.id))
    end
  end

  describe "inventory operations: give_item, remove_item, has_item?, get_inventory" do
    test "give_item/3 handles stackable items and max_stack limits" do
      user = create_user()

      {:ok, tmpl} =
        Inventory.create_item_template(item_template_attrs(%{is_stackable: true, max_stack: 5}))

      refute Inventory.has_item?(user.id, tmpl.id)

      assert {:ok, %InventoryItem{quantity: 2}} = Inventory.give_item(user.id, tmpl.id, 2)
      assert Inventory.has_item?(user.id, tmpl.id)

      # Stacking more items
      assert {:ok, %InventoryItem{quantity: 4}} = Inventory.give_item(user.id, tmpl.id, 2)

      # Exceeding max_stack clamps to max_stack (5)
      assert {:ok, %InventoryItem{quantity: 5}} = Inventory.give_item(user.id, tmpl.id, 5)

      inv = Inventory.get_inventory(user.id)
      assert length(inv) == 1
      assert hd(inv).item_template.id == tmpl.id
    end

    test "give_item/3 handles non-stackable items creating separate rows" do
      user = create_user()
      {:ok, tmpl} = Inventory.create_item_template(item_template_attrs(%{is_stackable: false}))

      assert {:ok, items} = Inventory.give_item(user.id, tmpl.id, 3)
      assert length(items) == 3

      inv = Inventory.get_inventory(user.id)
      assert length(inv) == 3
    end

    test "remove_item/3 decrements or deletes item" do
      user = create_user()

      {:ok, tmpl} =
        Inventory.create_item_template(item_template_attrs(%{is_stackable: true, max_stack: 20}))

      assert {:error, :item_not_found} = Inventory.remove_item(user.id, tmpl.id, 1)

      {:ok, _} = Inventory.give_item(user.id, tmpl.id, 5)

      # Partial removal
      assert {:ok, %InventoryItem{quantity: 3}} = Inventory.remove_item(user.id, tmpl.id, 2)

      # Complete removal deletes row
      assert {:ok, %InventoryItem{}} = Inventory.remove_item(user.id, tmpl.id, 3)
      refute Inventory.has_item?(user.id, tmpl.id)
      assert Inventory.get_inventory(user.id) == []
    end
  end

  describe "transfer_item/4" do
    test "transfers item between users with atomic rollback on failure" do
      user_a = create_user()
      user_b = create_user()

      {:ok, tmpl} =
        Inventory.create_item_template(item_template_attrs(%{is_stackable: true, max_stack: 50}))

      {:ok, _} = Inventory.give_item(user_a.id, tmpl.id, 10)

      # Successful transfer
      assert {:ok, %InventoryItem{quantity: 4}} =
               Inventory.transfer_item(user_a.id, user_b.id, tmpl.id, 4)

      assert Inventory.has_item?(user_b.id, tmpl.id)

      # Failed transfer: user_a doesn't have sufficient items when requesting removed from empty item
      {:ok, other_tmpl} = Inventory.create_item_template(item_template_attrs())

      assert {:error, :item_not_found} =
               Inventory.transfer_item(user_a.id, user_b.id, other_tmpl.id, 1)
    end
  end

  describe "equip_item/2 and consume_item/2" do
    test "equip_item/2 unequips other items in same category and equips target" do
      user = create_user()

      {:ok, sword1} =
        Inventory.create_item_template(
          item_template_attrs(%{category: "weapon", is_stackable: false})
        )

      {:ok, sword2} =
        Inventory.create_item_template(
          item_template_attrs(%{category: "weapon", is_stackable: false})
        )

      {:ok, [item1]} = Inventory.give_item(user.id, sword1.id, 1)
      {:ok, [item2]} = Inventory.give_item(user.id, sword2.id, 1)

      assert {:ok, equipped1} = Inventory.equip_item(user.id, item1.id)
      assert equipped1.is_equipped == true

      assert {:ok, equipped2} = Inventory.equip_item(user.id, item2.id)
      assert equipped2.is_equipped == true

      # item1 should now be unequipped
      reloaded1 = ForgeNexus.Repo.get!(InventoryItem, item1.id)
      refute reloaded1.is_equipped
    end

    test "consume_item/2 removes item and returns template" do
      user = create_user()

      {:ok, potion} =
        Inventory.create_item_template(
          item_template_attrs(%{
            name: "Health Potion",
            is_consumable: true,
            is_stackable: true
          })
        )

      {:ok, item} = Inventory.give_item(user.id, potion.id, 2)

      assert {:ok, returned_tmpl} = Inventory.consume_item(user.id, item.id)
      assert returned_tmpl.id == potion.id
      assert Inventory.has_item?(user.id, potion.id)

      # Consume last one
      assert {:ok, _} = Inventory.consume_item(user.id, item.id)
      refute Inventory.has_item?(user.id, potion.id)
    end
  end

  describe "crafting operations" do
    test "craft_item/2 verifies ingredients and outcomes" do
      user = create_user()
      {:ok, wood} = Inventory.create_item_template(item_template_attrs(%{name: "Wood"}))
      {:ok, iron} = Inventory.create_item_template(item_template_attrs(%{name: "Iron"}))
      {:ok, sword} = Inventory.create_item_template(item_template_attrs(%{name: "Crafted Sword"}))

      {:ok, recipe} =
        %CraftingRecipe{}
        |> CraftingRecipe.changeset(%{
          name: "Craft Sword",
          ingredients: [
            %{"item_template_id" => wood.id, "quantity" => 2},
            %{"item_template_id" => iron.id, "quantity" => 1}
          ],
          result_item_id: sword.id,
          result_quantity: 1,
          success_rate: 1.0,
          is_active: true
        })
        |> ForgeNexus.Repo.insert()

      recipes = Inventory.get_crafting_recipes()
      assert Enum.any?(recipes, &(&1.id == recipe.id))

      # Missing ingredients
      assert {:error, :missing_ingredient} = Inventory.craft_item(user.id, recipe.id)

      # Give only wood
      {:ok, _} = Inventory.give_item(user.id, wood.id, 5)
      assert {:error, :missing_ingredient} = Inventory.craft_item(user.id, recipe.id)

      # Give iron
      {:ok, _} = Inventory.give_item(user.id, iron.id, 2)

      # Success with 1.0 success_rate
      assert {:ok, {:success, _crafted}} = Inventory.craft_item(user.id, recipe.id)
      assert Inventory.has_item?(user.id, sword.id)

      # Verify ingredients were consumed (wood had 5, used 2 -> 3; iron had 2, used 1 -> 1)
      wood_item =
        ForgeNexus.Repo.get_by(InventoryItem, user_id: user.id, item_template_id: wood.id)

      assert wood_item.quantity == 3

      iron_item =
        ForgeNexus.Repo.get_by(InventoryItem, user_id: user.id, item_template_id: iron.id)

      assert iron_item.quantity == 1

      # Test failure rate
      {:ok, failed_recipe} =
        %CraftingRecipe{}
        |> CraftingRecipe.changeset(%{
          name: "Impossible Craft",
          ingredients: [%{"item_template_id" => wood.id, "quantity" => 1}],
          result_item_id: sword.id,
          result_quantity: 1,
          success_rate: 0.00000001,
          is_active: true
        })
        |> ForgeNexus.Repo.insert()

      assert {:ok, :failed} = Inventory.craft_item(user.id, failed_recipe.id)
    end
  end
end
