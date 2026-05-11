defmodule ForgeNexusWeb.SpaceController do
  use ForgeNexusWeb, :controller

  alias ForgeNexus.Spaces

  def index(conn, _params) do
    maps = Spaces.list_maps()
    conn |> json(%{maps: Enum.map(maps, &map_json/1)})
  end

  def show(conn, %{"slug" => slug}) do
    case safe(fn -> Spaces.get_map_by_slug!(slug) end) do
      nil ->
        conn |> put_status(:not_found) |> json(%{error: "space not found"})

      map ->
        rooms = Spaces.list_rooms(map.id)

        conn
        |> json(%{
          map: map_json(map),
          rooms: Enum.map(rooms, &room_json/1)
        })
    end
  end

  def room_users(conn, %{"id" => room_id}) do
    users = Spaces.get_users_in_room(room_id)

    conn
    |> json(%{
      users:
        Enum.map(users, fn u ->
          %{
            user_id: Map.get(u, :user_id),
            x: Map.get(u, :x),
            y: Map.get(u, :y),
            last_moved_at: Map.get(u, :last_moved_at)
          }
        end)
    })
  end

  defp safe(fun) do
    fun.()
  rescue
    Ecto.NoResultsError -> nil
  end

  defp map_json(m) do
    %{
      id: m.id,
      name: m.name,
      slug: m.slug,
      description: m.description,
      width: m.width,
      height: m.height,
      background_image_url: m.background_image_url,
      is_active: m.is_active
    }
  end

  defp room_json(r) do
    %{
      id: r.id,
      name: r.name,
      type: r.type,
      x: r.x,
      y: r.y,
      width: r.width,
      height: r.height,
      shape: r.shape,
      max_occupancy: r.max_occupancy,
      linked_resource_type: r.linked_resource_type,
      linked_resource_id: r.linked_resource_id
    }
  end
end
