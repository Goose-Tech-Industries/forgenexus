defmodule ForgeNexus.Collections.CollectionsSchemasTest do
  use ForgeNexus.DataCase, async: true

  alias ForgeNexus.Collections.{
    CollectionItem,
    CollectionSet,
    UserCollection
  }

  describe "CollectionSet" do
    test "valid changeset" do
      cs =
        CollectionSet.changeset(%CollectionSet{}, %{
          name: "Vintage Badges",
          description: "Old school forum badges",
          reward_points: 50
        })

      assert cs.valid?
      assert get_field(cs, :name) == "Vintage Badges"

      req_cs = CollectionSet.changeset(%CollectionSet{}, %{})
      refute req_cs.valid?
      assert "can't be blank" in errors_on(req_cs).name
    end
  end

  describe "CollectionItem" do
    @csid Ecto.UUID.generate()

    test "valid changeset" do
      cs =
        CollectionItem.changeset(%CollectionItem{}, %{
          name: "Gold Star",
          collection_set_id: @csid,
          rarity: "rare"
        })

      assert cs.valid?
      assert get_field(cs, :name) == "Gold Star"

      req_cs = CollectionItem.changeset(%CollectionItem{}, %{})
      refute req_cs.valid?
      assert "can't be blank" in errors_on(req_cs).name
      assert "can't be blank" in errors_on(req_cs).collection_set_id
    end
  end

  describe "UserCollection" do
    @uid Ecto.UUID.generate()
    @ciid Ecto.UUID.generate()

    test "valid changeset" do
      cs =
        UserCollection.changeset(%UserCollection{}, %{
          user_id: @uid,
          collection_item_id: @ciid
        })

      assert cs.valid?

      req_cs = UserCollection.changeset(%UserCollection{}, %{})
      refute req_cs.valid?
      assert "can't be blank" in errors_on(req_cs).user_id
      assert "can't be blank" in errors_on(req_cs).collection_item_id
    end
  end
end
