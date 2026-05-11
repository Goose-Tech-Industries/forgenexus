defmodule ForgeNexusWeb.ChannelController do
  use ForgeNexusWeb, :controller

  alias ForgeNexus.Channels

  def index(conn, _params) do
    user = Guardian.Plug.current_resource(conn)
    channels = Channels.list_channels_for_user(user)
    unread_counts = Channels.get_unread_counts(user.id)
    categories = channels
      |> Enum.group_by(fn ch -> ch.category end)
      |> Enum.sort_by(fn {cat, _} -> cat && cat.position || 999 end)
      |> Enum.map(fn {cat, chs} ->
        %{id: cat && cat.id, name: cat && cat.name, slug: cat && cat.slug,
          position: cat && cat.position, is_collapsed: cat && cat.is_collapsed,
          channels: Enum.map(chs, fn ch -> channel_json(ch, unread_counts) end)}
      end)
    conn |> json(%{categories: categories})
  end

  def show(conn, %{"slug" => slug}) do
    user = Guardian.Plug.current_resource(conn)
    case Channels.get_channel_by_slug(slug) do
      nil -> conn |> put_status(:not_found) |> json(%{error: "Channel not found"})
      channel ->
        if Channels.can_view_channel?(user, channel) do
          messages = Channels.list_messages(channel.id, limit: 50)
          conn |> json(%{channel: channel_detail_json(channel), messages: Enum.map(messages, &message_json/1)})
        else
          conn |> put_status(:forbidden) |> json(%{error: "Access denied"})
        end
    end
  end

  def messages(conn, %{"slug" => slug} = params) do
    user = Guardian.Plug.current_resource(conn)
    case Channels.get_channel_by_slug(slug) do
      nil -> conn |> put_status(:not_found) |> json(%{error: "Channel not found"})
      channel ->
        if Channels.can_view_channel?(user, channel) do
          opts = []
          opts = if params["before"], do: [{:before_id, params["before"]} | opts], else: opts
          opts = if params["limit"], do: [{:limit, safe_to_integer(params["limit"], 50)} | opts], else: opts
          messages = Channels.list_messages(channel.id, opts)
          conn |> json(%{messages: Enum.map(messages, &message_json/1)})
        else
          conn |> put_status(:forbidden) |> json(%{error: "Access denied"})
        end
    end
  end

  def create_message(conn, %{"slug" => slug} = params) do
    user = Guardian.Plug.current_resource(conn)
    case Channels.get_channel_by_slug(slug) do
      nil -> conn |> put_status(:not_found) |> json(%{error: "Channel not found"})
      channel ->
        if Channels.can_post_in_channel?(user, channel) do
          case Channels.check_slowmode(channel, user) do
            {:error, remaining} ->
              conn |> put_status(:too_many_requests) |> json(%{error: "Slowmode active", seconds_remaining: remaining})
            :ok ->
              attrs = %{body: params["body"], reply_to_id: params["reply_to_id"], attachments: params["attachments"] || [], embeds: params["embeds"] || []}
              case Channels.create_message(channel.id, user.id, attrs) do
                {:ok, message} ->
                  Phoenix.PubSub.broadcast(ForgeNexus.PubSub, "chat_channel:#{channel.id}", {:new_message, message})
                  conn |> put_status(:created) |> json(%{message: message_json(message)})
                {:error, _} -> conn |> put_status(:unprocessable_entity) |> json(%{error: "Failed to send message"})
              end
          end
        else
          conn |> put_status(:forbidden) |> json(%{error: "Cannot post in this channel"})
        end
    end
  end

  def update_message(conn, %{"slug" => _slug, "message_id" => message_id} = params) do
    user = Guardian.Plug.current_resource(conn)
    case Channels.get_message(message_id) do
      nil -> conn |> put_status(:not_found) |> json(%{error: "Message not found"})
      message ->
        if message.user_id == user.id do
          case Channels.update_message(message, %{body: params["body"]}) do
            {:ok, updated} ->
              Phoenix.PubSub.broadcast(ForgeNexus.PubSub, "chat_channel:#{message.channel_id}", {:message_edited, updated})
              conn |> json(%{message: message_json(updated)})
            {:error, _} -> conn |> put_status(:unprocessable_entity) |> json(%{error: "Failed to update"})
          end
        else
          conn |> put_status(:forbidden) |> json(%{error: "Can only edit own messages"})
        end
    end
  end

  def delete_message(conn, %{"slug" => _slug, "message_id" => message_id}) do
    user = Guardian.Plug.current_resource(conn)
    is_staff = ForgeNexus.Moderation.is_staff?(user.id)
    case Channels.get_message(message_id) do
      nil -> conn |> put_status(:not_found) |> json(%{error: "Message not found"})
      message ->
        if message.user_id == user.id or is_staff do
          case Channels.delete_message(message, user.id) do
            {:ok, _} ->
              Phoenix.PubSub.broadcast(ForgeNexus.PubSub, "chat_channel:#{message.channel_id}", {:message_deleted, message_id})
              conn |> json(%{ok: true})
            {:error, _} -> conn |> put_status(:unprocessable_entity) |> json(%{error: "Failed to delete"})
          end
        else
          conn |> put_status(:forbidden) |> json(%{error: "Cannot delete this message"})
        end
    end
  end

  def mark_read(conn, %{"slug" => slug} = params) do
    user = Guardian.Plug.current_resource(conn)
    case Channels.get_channel_by_slug(slug) do
      nil -> conn |> put_status(:not_found) |> json(%{error: "Channel not found"})
      channel ->
        Channels.mark_read(channel.id, user.id, params["message_id"])
        conn |> json(%{ok: true})
    end
  end

  def add_reaction(conn, %{"message_id" => message_id} = params) do
    user = Guardian.Plug.current_resource(conn)
    case Channels.add_reaction(message_id, user.id, params["emoji"]) do
      {:ok, _} -> conn |> json(%{ok: true})
      {:error, _} -> conn |> put_status(:unprocessable_entity) |> json(%{error: "Failed to add reaction"})
    end
  end

  def remove_reaction(conn, %{"message_id" => message_id, "emoji" => emoji}) do
    user = Guardian.Plug.current_resource(conn)
    case Channels.remove_reaction(message_id, user.id, emoji) do
      {:ok, _} -> conn |> json(%{ok: true})
      {:error, _} -> conn |> put_status(:unprocessable_entity) |> json(%{error: "Failed to remove reaction"})
    end
  end

  def pins(conn, %{"slug" => slug}) do
    user = Guardian.Plug.current_resource(conn)
    case Channels.get_channel_by_slug(slug) do
      nil -> conn |> put_status(:not_found) |> json(%{error: "Channel not found"})
      channel ->
        if Channels.can_view_channel?(user, channel) do
          messages = Channels.get_pinned_messages(channel.id)
          conn |> json(%{messages: Enum.map(messages, &message_json/1)})
        else
          conn |> put_status(:forbidden) |> json(%{error: "Access denied"})
        end
    end
  end

  def pin_message(conn, %{"message_id" => message_id}) do
    user = Guardian.Plug.current_resource(conn)
    if ForgeNexus.Moderation.is_staff?(user.id) do
      case Channels.get_message(message_id) do
        nil -> conn |> put_status(:not_found) |> json(%{error: "Message not found"})
        message ->
          case Channels.pin_message(message, user.id) do
            {:ok, _} -> conn |> json(%{ok: true})
            {:error, _} -> conn |> put_status(:unprocessable_entity) |> json(%{error: "Failed to pin"})
          end
      end
    else
      conn |> put_status(:forbidden) |> json(%{error: "Only staff can pin messages"})
    end
  end

  def unpin_message(conn, %{"message_id" => message_id}) do
    user = Guardian.Plug.current_resource(conn)
    if ForgeNexus.Moderation.is_staff?(user.id) do
      case Channels.get_message(message_id) do
        nil -> conn |> put_status(:not_found) |> json(%{error: "Message not found"})
        message ->
          case Channels.unpin_message(message) do
            {:ok, _} -> conn |> json(%{ok: true})
            {:error, _} -> conn |> put_status(:unprocessable_entity) |> json(%{error: "Failed to unpin"})
          end
      end
    else
      conn |> put_status(:forbidden) |> json(%{error: "Only staff can unpin messages"})
    end
  end

  def update_settings(conn, %{"slug" => slug} = params) do
    user = Guardian.Plug.current_resource(conn)
    case Channels.get_channel_by_slug(slug) do
      nil -> conn |> put_status(:not_found) |> json(%{error: "Channel not found"})
      channel ->
        if params["notification_level"], do: Channels.set_notification_level(channel.id, user.id, params["notification_level"])
        case params["is_muted"] do
          true -> Channels.mute_channel(channel.id, user.id)
          false -> Channels.unmute_channel(channel.id, user.id)
          _ -> :noop
        end
        conn |> json(%{ok: true})
    end
  end

  def search(conn, params) do
    user = Guardian.Plug.current_resource(conn)
    query = params["q"] || ""

    if String.length(String.trim(query)) < 2 do
      conn |> json(%{messages: [], total: 0})
    else
      opts = [
        channel: params["channel"],
        user_id: params["user_id"],
        has: params["has"],
        limit: min(safe_to_integer(params["limit"] || "25", 25), 50),
        offset: safe_to_integer(params["offset"] || "0", 0)
      ]

      messages = Channels.search_messages(user, query, opts)

      conn |> json(%{
        messages: Enum.map(messages, &search_result_json/1),
        total: length(messages)
      })
    end
  end

  defp search_result_json(message) do
    base = message_json(message)
    Map.put(base, :channel_name, message.channel && message.channel.name)
    |> Map.put(:channel_slug, message.channel && message.channel.slug)
  end

  defp channel_json(ch, unread_counts) do
    %{id: ch.id, name: ch.name, slug: ch.slug, description: ch.description, topic: ch.topic, type: ch.type, icon: ch.icon, color: ch.color, position: ch.position, is_private: ch.is_private, is_read_only: ch.is_read_only, is_nsfw: ch.is_nsfw, is_archived: ch.is_archived, slowmode_seconds: ch.slowmode_seconds, message_count: ch.message_count, last_message_at: ch.last_message_at, unread_count: Map.get(unread_counts, ch.id, 0)}
  end

  defp channel_detail_json(ch) do
    %{id: ch.id, name: ch.name, slug: ch.slug, description: ch.description, topic: ch.topic, type: ch.type, icon: ch.icon, color: ch.color, position: ch.position, is_private: ch.is_private, is_read_only: ch.is_read_only, is_nsfw: ch.is_nsfw, is_archived: ch.is_archived, slowmode_seconds: ch.slowmode_seconds, message_count: ch.message_count, last_message_at: ch.last_message_at, category: ch.category && %{id: ch.category.id, name: ch.category.name, slug: ch.category.slug}}
  end

  defp message_json(message) do
    user = message.user
    group = user && user.primary_group
    %{
      id: message.id, body: message.body, channel_id: message.channel_id,
      user: user && %{id: user.id, username: user.username, slug: user.slug, avatar_url: user.avatar_url,
        username_color: user.username_color || (group && group.username_color) || (group && group.color),
        username_effect: user.username_effect || (group && group.username_effect) || "none",
        avatar_frame: user.avatar_frame, custom_title: user.custom_title},
      is_edited: message.is_edited, edited_at: message.edited_at, is_pinned: message.is_pinned,
      is_deleted: message.is_deleted,
      reply_to: message.reply_to && reply_preview_json(message.reply_to),
      attachments: message.attachments, embeds: message.embeds,
      reactions: format_reactions(message),
      thread: message_thread_info(message),
      inserted_at: message.inserted_at
    }
  end

  defp message_thread_info(message) do
    if Ecto.assoc_loaded?(message.spawned_thread) && message.spawned_thread do
      t = message.spawned_thread
      %{id: t.id, name: t.name, message_count: t.message_count, last_message_at: t.last_message_at}
    else
      nil
    end
  end

  defp reply_preview_json(reply) do
    user = reply.user
    %{id: reply.id, body: String.slice(reply.body || "", 0, 200), user: user && %{id: user.id, username: user.username, avatar_url: user.avatar_url}}
  end

  defp format_reactions(message) do
    if Ecto.assoc_loaded?(message.reactions) do
      message.reactions
      |> Enum.group_by(fn r -> r.emoji end)
      |> Enum.map(fn {emoji, group} ->
        %{emoji: emoji, count: length(group), user_ids: Enum.map(group, fn r -> r.user_id end)}
      end)
    else
      []
    end
  end

  defp safe_to_integer(val, default) when is_binary(val) do
    case Integer.parse(val) do
      {int, _} -> int
      :error -> default
    end
  end
  defp safe_to_integer(val, _default) when is_integer(val), do: val
  defp safe_to_integer(_, default), do: default

end
