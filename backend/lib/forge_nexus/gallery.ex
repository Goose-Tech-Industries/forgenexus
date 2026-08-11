defmodule ForgeNexus.Gallery do
  @moduledoc "User photo albums and media management."
  import Ecto.Query
  alias ForgeNexus.Repo
  alias ForgeNexus.Gallery.{Album, MediaItem}

  def list_user_albums(user_id) do
    Album
    |> where([a], a.user_id == ^user_id)
    |> order_by(asc: :position)
    |> preload(:items)
    |> Repo.all()
  end

  def list_public_albums(user_id) do
    Album
    |> where([a], a.user_id == ^user_id and a.is_public == true)
    |> order_by(asc: :position)
    |> Repo.all()
  end

  def get_album!(id),
    do:
      Album |> preload(items: ^from(i in MediaItem, order_by: [asc: :position])) |> Repo.get!(id)

  def create_album(attrs), do: %Album{} |> Album.changeset(attrs) |> Repo.insert()

  def update_album(id, attrs), do: Repo.get!(Album, id) |> Album.changeset(attrs) |> Repo.update()

  def delete_album(id), do: Repo.get!(Album, id) |> Repo.delete()

  def add_media(album_id, user_id, attrs) do
    Repo.transaction(fn ->
      item =
        %MediaItem{}
        |> MediaItem.changeset(Map.merge(attrs, %{album_id: album_id, user_id: user_id}))
        |> Repo.insert!()

      from(a in Album, where: a.id == ^album_id) |> Repo.update_all(inc: [media_count: 1])
      item
    end)
  end

  def remove_media(item_id) do
    item = Repo.get!(MediaItem, item_id)

    Repo.transaction(fn ->
      Repo.delete!(item)
      from(a in Album, where: a.id == ^item.album_id) |> Repo.update_all(inc: [media_count: -1])
    end)
  end

  def recent_media(limit \\ 20) do
    MediaItem
    |> join(:inner, [m], a in Album, on: m.album_id == a.id and a.is_public == true)
    |> order_by(desc: :inserted_at)
    |> limit(^limit)
    |> preload([:user, :album])
    |> Repo.all()
  end
end
