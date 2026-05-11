defmodule ForgeNexusWeb.GalleryController do
  use ForgeNexusWeb, :controller
  alias ForgeNexus.Gallery

  def user_albums(conn, %{"user_id" => user_id}) do
    albums = Gallery.list_public_albums(user_id)
    conn |> json(%{albums: Enum.map(albums, &album_json/1)})
  end

  def my_albums(conn, _params) do
    user = Guardian.Plug.current_resource(conn)
    albums = Gallery.list_user_albums(user.id)
    conn |> json(%{albums: Enum.map(albums, &album_json/1)})
  end

  def show(conn, %{"id" => id}) do
    album = Gallery.get_album!(id)
    conn |> json(%{album: album_json(album), items: Enum.map(album.items, &item_json/1)})
  end

  def create(conn, params) do
    user = Guardian.Plug.current_resource(conn)
    attrs = Map.put(params, "user_id", user.id)
    case Gallery.create_album(attrs) do
      {:ok, album} -> conn |> put_status(:created) |> json(%{album: album_json(album)})
      {:error, cs} -> conn |> put_status(:unprocessable_entity) |> json(%{error: format_errors(cs)})
    end
  end

  def update(conn, %{"id" => id} = params) do
    case Gallery.update_album(id, params) do
      {:ok, album} -> conn |> json(%{album: album_json(album)})
      {:error, _} -> conn |> put_status(:unprocessable_entity) |> json(%{error: "Failed"})
    end
  end

  def delete(conn, %{"id" => id}) do
    case Gallery.delete_album(id) do
      {:ok, _} -> conn |> json(%{ok: true})
      _ -> conn |> put_status(:unprocessable_entity) |> json(%{error: "Failed"})
    end
  end

  def add_media(conn, %{"album_id" => album_id} = params) do
    user = Guardian.Plug.current_resource(conn)
    case Gallery.add_media(album_id, user.id, params) do
      {:ok, item} -> conn |> put_status(:created) |> json(%{item: item_json(item)})
      {:error, _} -> conn |> put_status(:unprocessable_entity) |> json(%{error: "Failed"})
    end
  end

  def remove_media(conn, %{"id" => id}) do
    case Gallery.remove_media(id) do
      {:ok, _} -> conn |> json(%{ok: true})
      _ -> conn |> put_status(:unprocessable_entity) |> json(%{error: "Failed"})
    end
  end

  def recent(conn, _params) do
    items = Gallery.recent_media()
    conn |> json(%{items: Enum.map(items, &item_json/1)})
  end

  defp album_json(a) do
    %{id: a.id, title: a.title, description: a.description, is_public: a.is_public,
      cover_image_url: a.cover_image_url, media_count: a.media_count, inserted_at: a.inserted_at}
  end

  defp item_json(i) do
    %{id: i.id, file_url: i.file_url, thumbnail_url: i.thumbnail_url, file_type: i.file_type,
      file_size: i.file_size, width: i.width, height: i.height, caption: i.caption, inserted_at: i.inserted_at}
  end

  defp format_errors(cs), do: Ecto.Changeset.traverse_errors(cs, fn {msg, _} -> msg end)
end
