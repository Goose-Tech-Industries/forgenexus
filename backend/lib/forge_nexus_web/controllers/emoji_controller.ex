defmodule ForgeNexusWeb.EmojiController do
  use ForgeNexusWeb, :controller

  alias ForgeNexus.Channels

  # Public — list active emojis
  def index(conn, _params) do
    emojis = Channels.list_custom_emojis()
    conn |> json(%{emojis: Enum.map(emojis, &emoji_json/1)})
  end

  # Admin — list all emojis
  def admin_index(conn, _params) do
    emojis = Channels.list_all_custom_emojis()
    conn |> json(%{emojis: Enum.map(emojis, &emoji_json/1)})
  end

  def create(conn, params) do
    user = Guardian.Plug.current_resource(conn)
    attrs = Map.put(params, "created_by_id", user.id)

    case Channels.create_custom_emoji(attrs) do
      {:ok, emoji} ->
        conn |> put_status(:created) |> json(%{emoji: emoji_json(emoji)})

      {:error, changeset} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: format_errors(changeset)})
    end
  end

  def update(conn, %{"id" => id} = params) do
    case Channels.update_custom_emoji(id, params) do
      {:ok, emoji} ->
        conn |> json(%{emoji: emoji_json(emoji)})

      {:error, changeset} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: format_errors(changeset)})
    end
  end

  def delete(conn, %{"id" => id}) do
    case Channels.delete_custom_emoji(id) do
      {:ok, _} ->
        conn |> json(%{ok: true})

      {:error, _} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: "Failed to delete"})
    end
  end

  defp emoji_json(emoji) do
    %{
      id: emoji.id,
      name: emoji.name,
      shortcode: emoji.shortcode,
      image_url: emoji.image_url,
      category: emoji.category,
      is_animated: emoji.is_animated,
      is_active: emoji.is_active
    }
  end

  defp format_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, _opts} -> msg end)
  end
end
