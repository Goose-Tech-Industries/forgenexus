defmodule ForgeNexusWeb.AdminChannelController do
  use ForgeNexusWeb, :controller

  alias ForgeNexus.{Channels, Admin}

  # Categories

  def list_categories(conn, _params) do
    categories = Channels.list_categories()
    conn |> json(%{categories: Enum.map(categories, &category_json/1)})
  end

  def create_category(conn, %{"category" => params}) do
    case Channels.create_category(atomize_keys(params)) do
      {:ok, cat} ->
        admin = Guardian.Plug.current_resource(conn)

        Admin.log_admin_action(admin.id, %{
          action: "chat_category_created",
          category: "chat",
          target_type: "chat_category",
          target_id: cat.id,
          description: "Created chat category #{cat.name}",
          new_state: params
        })

        conn
        |> put_status(:created)
        |> json(%{category: category_json(ForgeNexus.Repo.preload(cat, :channels))})

      {:error, cs} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: cs_errors(cs)})
    end
  end

  def update_category(conn, %{"id" => id, "category" => params}) do
    cat = Channels.get_category!(id)

    case Channels.update_category(cat, atomize_keys(params)) do
      {:ok, updated} ->
        admin = Guardian.Plug.current_resource(conn)

        Admin.log_admin_action(admin.id, %{
          action: "chat_category_updated",
          category: "chat",
          target_type: "chat_category",
          target_id: id,
          description: "Updated chat category #{cat.name}",
          new_state: params
        })

        conn |> json(%{category: category_json(ForgeNexus.Repo.preload(updated, :channels))})

      {:error, cs} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: cs_errors(cs)})
    end
  end

  def delete_category(conn, %{"id" => id}) do
    case Channels.delete_category(id) do
      {:ok, cat} ->
        admin = Guardian.Plug.current_resource(conn)

        Admin.log_admin_action(admin.id, %{
          action: "chat_category_deleted",
          category: "chat",
          target_type: "chat_category",
          target_id: id,
          description: "Deleted chat category #{cat.name}"
        })

        conn |> json(%{ok: true})

      {:error, _} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: "Failed to delete category"})
    end
  end

  def reorder_categories(conn, %{"ordered_ids" => ordered_ids}) do
    case Channels.reorder_categories(ordered_ids) do
      {:ok, _} ->
        admin = Guardian.Plug.current_resource(conn)

        Admin.log_admin_action(admin.id, %{
          action: "chat_categories_reordered",
          category: "chat",
          target_type: "chat_category",
          description: "Reordered chat categories"
        })

        conn |> json(%{ok: true})

      {:error, _} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: "Failed to reorder"})
    end
  end

  # Channels

  def list_channels(conn, _params) do
    channels = Channels.list_channels()
    conn |> json(%{channels: Enum.map(channels, &channel_json/1)})
  end

  def create_channel(conn, %{"channel" => params}) do
    case Channels.create_channel(atomize_keys(params)) do
      {:ok, ch} ->
        admin = Guardian.Plug.current_resource(conn)

        Admin.log_admin_action(admin.id, %{
          action: "chat_channel_created",
          category: "chat",
          target_type: "chat_channel",
          target_id: ch.id,
          description: "Created channel ##{ch.name}",
          new_state: params
        })

        conn
        |> put_status(:created)
        |> json(%{channel: channel_json(ForgeNexus.Repo.preload(ch, :category))})

      {:error, cs} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: cs_errors(cs)})
    end
  end

  def update_channel(conn, %{"id" => id, "channel" => params}) do
    channel = Channels.get_channel!(id)

    case Channels.update_channel(channel, atomize_keys(params)) do
      {:ok, updated} ->
        admin = Guardian.Plug.current_resource(conn)

        Admin.log_admin_action(admin.id, %{
          action: "chat_channel_updated",
          category: "chat",
          target_type: "chat_channel",
          target_id: id,
          description: "Updated channel ##{channel.name}",
          new_state: params
        })

        conn |> json(%{channel: channel_json(ForgeNexus.Repo.preload(updated, :category))})

      {:error, cs} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: cs_errors(cs)})
    end
  end

  def delete_channel(conn, %{"id" => id}) do
    case Channels.delete_channel(id) do
      {:ok, ch} ->
        admin = Guardian.Plug.current_resource(conn)

        Admin.log_admin_action(admin.id, %{
          action: "chat_channel_deleted",
          category: "chat",
          target_type: "chat_channel",
          target_id: id,
          description: "Deleted channel ##{ch.name}"
        })

        conn |> json(%{ok: true})

      {:error, _} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: "Failed to delete channel"})
    end
  end

  def archive_channel(conn, %{"id" => id}) do
    channel = Channels.get_channel!(id)

    case Channels.archive_channel(channel) do
      {:ok, _} ->
        admin = Guardian.Plug.current_resource(conn)

        Admin.log_admin_action(admin.id, %{
          action: "chat_channel_archived",
          category: "chat",
          target_type: "chat_channel",
          target_id: id,
          description: "Archived channel ##{channel.name}"
        })

        conn |> json(%{ok: true})

      {:error, _} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: "Failed to archive"})
    end
  end

  def unarchive_channel(conn, %{"id" => id}) do
    channel = Channels.get_channel!(id)

    case Channels.unarchive_channel(channel) do
      {:ok, _} ->
        admin = Guardian.Plug.current_resource(conn)

        Admin.log_admin_action(admin.id, %{
          action: "chat_channel_unarchived",
          category: "chat",
          target_type: "chat_channel",
          target_id: id,
          description: "Unarchived channel ##{channel.name}"
        })

        conn |> json(%{ok: true})

      {:error, _} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: "Failed to unarchive"})
    end
  end

  def reorder_channels(conn, %{"category_id" => category_id, "ordered_ids" => ordered_ids}) do
    case Channels.reorder_channels(category_id, ordered_ids) do
      {:ok, _} ->
        admin = Guardian.Plug.current_resource(conn)

        Admin.log_admin_action(admin.id, %{
          action: "chat_channels_reordered",
          category: "chat",
          target_type: "chat_channel",
          description: "Reordered channels"
        })

        conn |> json(%{ok: true})

      {:error, _} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: "Failed to reorder"})
    end
  end

  # Message management

  def delete_message(conn, %{"id" => id}) do
    case Channels.hard_delete_message(id) do
      {:ok, msg} ->
        admin = Guardian.Plug.current_resource(conn)

        Admin.log_admin_action(admin.id, %{
          action: "chat_message_deleted",
          category: "chat",
          target_type: "chat_message",
          target_id: id,
          description: "Hard-deleted a chat message"
        })

        Phoenix.PubSub.broadcast(
          ForgeNexus.PubSub,
          "chat_channel:#{msg.channel_id}",
          {:message_deleted, id}
        )

        conn |> json(%{ok: true})

      {:error, _} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: "Failed to delete"})
    end
  end

  # JSON helpers

  defp category_json(cat) do
    %{
      id: cat.id,
      name: cat.name,
      slug: cat.slug,
      position: cat.position,
      is_collapsed: cat.is_collapsed,
      inserted_at: cat.inserted_at,
      channels:
        if(Ecto.assoc_loaded?(cat.channels),
          do: Enum.map(cat.channels, &channel_json/1),
          else: []
        )
    }
  end

  defp channel_json(ch) do
    %{
      id: ch.id,
      name: ch.name,
      slug: ch.slug,
      description: ch.description,
      topic: ch.topic,
      type: ch.type,
      icon: ch.icon,
      color: ch.color,
      position: ch.position,
      category_id: ch.category_id,
      is_private: ch.is_private,
      allowed_group_ids: ch.allowed_group_ids,
      is_read_only: ch.is_read_only,
      slowmode_seconds: ch.slowmode_seconds,
      is_nsfw: ch.is_nsfw,
      is_archived: ch.is_archived,
      message_count: ch.message_count,
      last_message_at: ch.last_message_at,
      inserted_at: ch.inserted_at
    }
  end

  defp atomize_keys(map) do
    Map.new(map, fn
      {k, v} when is_binary(k) ->
        try do
          {String.to_existing_atom(k), v}
        rescue
          _ -> {k, v}
        end

      {k, v} ->
        {k, v}
    end)
  end

  defp cs_errors(%Ecto.Changeset{} = cs),
    do: Ecto.Changeset.traverse_errors(cs, fn {msg, _} -> msg end)

  defp cs_errors(err), do: inspect(err)
end
