defmodule ForgeNexus.SpacesTest do
  use ForgeNexus.DataCase, async: true

  alias ForgeNexus.Spaces
  alias ForgeNexus.Spaces.{CommunityMap, MapRoom, UserPosition}
  alias ForgeNexus.Accounts

  defp create_user do
    unique = System.unique_integer([:positive])

    {:ok, user} =
      Accounts.register_user(%{
        username: "space_u_#{unique}",
        email: "space_u_#{unique}@example.com",
        password: "ValidPassword123!@#"
      })

    user
  end

  defp map_attrs(attrs \\ %{}) do
    unique = System.unique_integer([:positive])

    Enum.into(attrs, %{
      name: "Nexus Hub #{unique}",
      slug: "nexus-hub-#{unique}",
      description: "Central meeting space",
      width: 1920,
      height: 1080,
      is_active: true
    })
  end

  defp room_attrs(map_id, attrs \\ %{}) do
    unique = System.unique_integer([:positive])

    Enum.into(attrs, %{
      name: "Tavern #{unique}",
      type: "general",
      x: 100,
      y: 100,
      width: 300,
      height: 200,
      map_id: map_id
    })
  end

  describe "maps CRUD and listing" do
    test "create, get, get_by_slug, list, update, and delete maps" do
      attrs = map_attrs(%{name: "Alpha Map"})
      assert {:ok, %CommunityMap{} = map} = Spaces.create_map(attrs)

      assert %CommunityMap{id: id} = Spaces.get_map!(map.id)
      assert id == map.id

      assert %CommunityMap{slug: slug} = Spaces.get_map_by_slug!(map.slug)
      assert slug == map.slug

      maps = Spaces.list_maps()
      assert Enum.any?(maps, &(&1.id == map.id))

      assert {:ok, updated} = Spaces.update_map(map, %{description: "Updated description"})
      assert updated.description == "Updated description"

      assert {:ok, %CommunityMap{}} = Spaces.delete_map(map)
      refute Enum.any?(Spaces.list_maps(), &(&1.id == map.id))
    end
  end

  describe "rooms CRUD" do
    test "create, list, update, and delete rooms" do
      {:ok, map} = Spaces.create_map(map_attrs())
      attrs = room_attrs(map.id, %{name: "Lobby"})

      assert {:ok, %MapRoom{} = room} = Spaces.create_room(attrs)

      rooms = Spaces.list_rooms(map.id)
      assert length(rooms) == 1
      assert hd(rooms).id == room.id

      assert {:ok, updated} = Spaces.update_room(room, %{name: "Grand Lobby"})
      assert updated.name == "Grand Lobby"

      assert {:ok, %MapRoom{}} = Spaces.delete_room(room)
      assert Spaces.list_rooms(map.id) == []
    end
  end

  describe "user positions" do
    test "update_user_position/3 inserts new and updates existing position" do
      user = create_user()
      {:ok, map} = Spaces.create_map(map_attrs())
      {:ok, room} = Spaces.create_room(room_attrs(map.id))

      assert Spaces.get_users_in_map(map.id) == []
      assert Spaces.get_users_in_room(room.id) == []

      # Initial position
      assert {:ok, %UserPosition{} = pos1} =
               Spaces.update_user_position(user.id, map.id, %{x: 50.0, y: 75.0, room_id: room.id})

      assert pos1.x == 50.0
      assert pos1.y == 75.0
      assert pos1.room_id == room.id

      # Users in map and room
      in_map = Spaces.get_users_in_map(map.id)
      assert length(in_map) == 1
      assert hd(in_map).user.id == user.id

      in_room = Spaces.get_users_in_room(room.id)
      assert length(in_room) == 1
      assert hd(in_room).user.id == user.id

      # Update position
      assert {:ok, %UserPosition{} = pos2} =
               Spaces.update_user_position(user.id, map.id, %{x: 120.0, y: 150.0, room_id: nil})

      assert pos2.x == 120.0
      assert pos2.y == 150.0
      assert is_nil(pos2.room_id)

      assert Spaces.get_users_in_room(room.id) == []
      assert length(Spaces.get_users_in_map(map.id)) == 1
    end
  end
end
