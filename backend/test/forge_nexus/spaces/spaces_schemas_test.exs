defmodule ForgeNexus.Spaces.SpacesSchemasTest do
  use ForgeNexus.DataCase, async: true

  alias ForgeNexus.Spaces.{
    CommunityMap,
    MapRoom,
    UserPosition
  }

  describe "CommunityMap" do
    test "valid changeset" do
      cs =
        CommunityMap.changeset(%CommunityMap{}, %{
          name: "Central Plaza",
          slug: "central-plaza",
          width: 1920,
          height: 1080,
          is_default: true
        })

      assert cs.valid?
      assert get_field(cs, :width) == 1920

      req_cs = CommunityMap.changeset(%CommunityMap{}, %{})
      refute req_cs.valid?
      assert "can't be blank" in errors_on(req_cs).name
      assert "can't be blank" in errors_on(req_cs).slug
      assert "can't be blank" in errors_on(req_cs).width
      assert "can't be blank" in errors_on(req_cs).height
    end
  end

  describe "MapRoom" do
    @mid Ecto.UUID.generate()

    test "valid changeset" do
      cs =
        MapRoom.changeset(%MapRoom{}, %{
          name: "Town Hall",
          x: 100,
          y: 200,
          width: 300,
          height: 400,
          map_id: @mid
        })

      assert cs.valid?
      assert get_field(cs, :name) == "Town Hall"

      req_cs = MapRoom.changeset(%MapRoom{}, %{})
      refute req_cs.valid?
      assert "can't be blank" in errors_on(req_cs).name
      assert "can't be blank" in errors_on(req_cs).x
      assert "can't be blank" in errors_on(req_cs).y
      assert "can't be blank" in errors_on(req_cs).width
      assert "can't be blank" in errors_on(req_cs).height
      assert "can't be blank" in errors_on(req_cs).map_id
    end
  end

  describe "UserPosition" do
    @uid Ecto.UUID.generate()
    @mid Ecto.UUID.generate()

    test "valid changeset" do
      cs =
        UserPosition.changeset(%UserPosition{}, %{
          x: 150.5,
          y: 300.25,
          user_id: @uid,
          map_id: @mid,
          last_moved_at: ~U[2026-03-01 12:00:00Z]
        })

      assert cs.valid?
      assert get_field(cs, :x) == 150.5

      req_cs = UserPosition.changeset(%UserPosition{}, %{})
      refute req_cs.valid?
      assert "can't be blank" in errors_on(req_cs).x
      assert "can't be blank" in errors_on(req_cs).y
      assert "can't be blank" in errors_on(req_cs).user_id
      assert "can't be blank" in errors_on(req_cs).map_id
    end
  end
end
