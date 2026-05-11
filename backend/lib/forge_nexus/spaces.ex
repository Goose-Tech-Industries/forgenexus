defmodule ForgeNexus.Spaces do
  @moduledoc """
  The Spaces context. Manages community maps, rooms, and user positions
  for the visual spatial interface.
  """

  import Ecto.Query, warn: false
  alias ForgeNexus.Repo

  alias ForgeNexus.Spaces.{CommunityMap, MapRoom, UserPosition}

  # ── Maps ──

  def list_maps do
    CommunityMap
    |> where([m], m.is_active == true)
    |> order_by([m], asc: m.name)
    |> Repo.all()
  end

  def get_map!(id) do
    CommunityMap
    |> Repo.get!(id)
    |> Repo.preload(:rooms)
  end

  def get_map_by_slug!(slug) do
    CommunityMap
    |> Repo.get_by!(slug: slug)
    |> Repo.preload(:rooms)
  end

  def create_map(attrs \\ %{}) do
    %CommunityMap{}
    |> CommunityMap.changeset(attrs)
    |> Repo.insert()
  end

  def update_map(%CommunityMap{} = map, attrs) do
    map
    |> CommunityMap.changeset(attrs)
    |> Repo.update()
  end

  def delete_map(%CommunityMap{} = map) do
    Repo.delete(map)
  end

  # ── Rooms ──

  def list_rooms(map_id) do
    MapRoom
    |> where([r], r.map_id == ^map_id)
    |> order_by([r], asc: r.name)
    |> Repo.all()
  end

  def create_room(attrs \\ %{}) do
    %MapRoom{}
    |> MapRoom.changeset(attrs)
    |> Repo.insert()
  end

  def update_room(%MapRoom{} = room, attrs) do
    room
    |> MapRoom.changeset(attrs)
    |> Repo.update()
  end

  def delete_room(%MapRoom{} = room) do
    Repo.delete(room)
  end

  # ── User Positions ──

  def update_user_position(user_id, map_id, %{x: x, y: y} = attrs) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    room_id = Map.get(attrs, :room_id)

    case Repo.get_by(UserPosition, user_id: user_id, map_id: map_id) do
      nil ->
        %UserPosition{}
        |> UserPosition.changeset(%{
          user_id: user_id,
          map_id: map_id,
          x: x,
          y: y,
          room_id: room_id,
          last_moved_at: now
        })
        |> Repo.insert()

      existing ->
        existing
        |> UserPosition.changeset(%{
          x: x,
          y: y,
          room_id: room_id,
          last_moved_at: now
        })
        |> Repo.update()
    end
  end

  def get_users_in_map(map_id) do
    UserPosition
    |> where([p], p.map_id == ^map_id)
    |> preload(:user)
    |> Repo.all()
  end

  def get_users_in_room(room_id) do
    UserPosition
    |> where([p], p.room_id == ^room_id)
    |> preload(:user)
    |> Repo.all()
  end
end
