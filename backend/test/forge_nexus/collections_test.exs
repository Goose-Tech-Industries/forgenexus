defmodule ForgeNexus.CollectionsTest do
  use ForgeNexus.DataCase, async: true

  alias ForgeNexus.Collections
  alias ForgeNexus.Collections.CollectionSet
  alias ForgeNexus.Accounts

  defp create_user do
    unique = System.unique_integer([:positive])

    {:ok, user} =
      Accounts.register_user(%{
        username: "coll_u_#{unique}",
        email: "coll_u_#{unique}@example.com",
        password: "ValidPassword123!@#"
      })

    user
  end

  defp set_attrs(attrs \\ %{}) do
    unique = System.unique_integer([:positive])

    Enum.into(attrs, %{
      name: "Vintage Relics #{unique}",
      description: "A rare collection of relics",
      icon: "relic.png",
      reward_points: 100,
      is_active: true
    })
  end

  describe "sets and items definitions" do
    test "create_set/1, define_set/1, get_set!/1, list_sets/0" do
      attrs = set_attrs(%{name: "Alpha Relics"})
      assert {:ok, %CollectionSet{} = set1} = Collections.create_set(attrs)

      attrs2 = set_attrs(%{name: "Beta Relics"})
      assert {:ok, %CollectionSet{} = set2} = Collections.define_set(attrs2)

      assert %CollectionSet{id: id} = Collections.get_set!(set1.id)
      assert id == set1.id

      sets = Collections.list_sets()
      ids = Enum.map(sets, & &1.id)
      assert set1.id in ids
      assert set2.id in ids
    end

    test "add_items_to_set/2 adds valid items or returns errors on invalid" do
      {:ok, set} = Collections.create_set(set_attrs())

      items_attrs = [
        %{name: "Relic A", rarity: "common", sort_order: 1},
        %{name: "Relic B", rarity: "rare", sort_order: 2}
      ]

      assert {:ok, items} = Collections.add_items_to_set(set.id, items_attrs)
      assert length(items) == 2

      # Failure case: missing name
      bad_items = [%{name: nil}]
      assert {:error, errors} = Collections.add_items_to_set(set.id, bad_items)
      assert length(errors) == 1
    end
  end

  describe "user collection progress and completion" do
    test "add_to_user_collection/2, check_completion?/2, get_missing_items/2, get_progress/2" do
      user = create_user()
      {:ok, set} = Collections.create_set(set_attrs())

      {:ok, [item1, item2]} =
        Collections.add_items_to_set(set.id, [
          %{name: "Item 1", sort_order: 1},
          %{name: "Item 2", sort_order: 2}
        ])

      # Initially no items collected
      assert Collections.check_completion?(user.id, set.id) == false
      assert length(Collections.get_missing_items(user.id, set.id)) == 2
      assert {:ok, missing} = Collections.get_missing(user.id, set.id)
      assert length(missing) == 2

      # Collect first item
      assert {:ok, {1, 2, _items}} = Collections.add_to_user_collection(user.id, item1.id)
      assert Collections.check_completion?(user.id, set.id) == false
      assert length(Collections.get_missing_items(user.id, set.id)) == 1

      # Attempting duplicate collection returns error
      assert {:error, :already_collected} = Collections.add_to_user_collection(user.id, item1.id)

      # Collect second item using add_to_set alias
      assert {:ok, {2, 2, _items}} = Collections.add_to_set(user.id, item2.id)
      assert Collections.check_completion?(user.id, set.id) == true
      assert Collections.get_missing_items(user.id, set.id) == []

      # get_progress/2
      assert {:ok, progress} = Collections.get_progress(user.id, set.id)
      assert progress.collected == 2
      assert progress.total == 2
      assert progress.complete == true
    end

    test "check_completion?/2 returns false when set has no items" do
      user = create_user()
      {:ok, empty_set} = Collections.create_set(set_attrs())
      refute Collections.check_completion?(user.id, empty_set.id)
    end
  end

  describe "trade_item/3" do
    test "trades collected item from user_a to user_b" do
      user_a = create_user()
      user_b = create_user()
      {:ok, set} = Collections.create_set(set_attrs())
      {:ok, [item]} = Collections.add_items_to_set(set.id, [%{name: "Coin"}])

      # Fail trade when user_a does not own item
      assert {:error, :not_owned} = Collections.trade_item(user_a.id, user_b.id, item.id)

      # user_a collects item
      {:ok, _} = Collections.add_to_user_collection(user_a.id, item.id)

      # Trade succeeds
      assert {:ok, :ok} = Collections.trade_item(user_a.id, user_b.id, item.id)

      # Now user_b has it, user_a does not
      assert Collections.check_completion?(user_b.id, set.id) == true
      assert Collections.check_completion?(user_a.id, set.id) == false
    end
  end
end
