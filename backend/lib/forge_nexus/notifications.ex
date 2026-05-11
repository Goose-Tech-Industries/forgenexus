defmodule ForgeNexus.Notifications do
  @moduledoc """
  The Notifications context -- manages user notifications for mentions, replies, reactions, etc.
  """
  import Ecto.Query
  alias ForgeNexus.Repo
  alias ForgeNexus.Chat.Notification

  def create_notification(attrs) do
    %Notification{}
    |> Notification.changeset(attrs)
    |> Repo.insert()
  end

  def list_notifications(user_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 20)
    offset = Keyword.get(opts, :offset, 0)
    unread_only = Keyword.get(opts, :unread_only, false)

    query =
      from(n in Notification,
        where: n.user_id == ^user_id,
        order_by: [desc: n.inserted_at],
        limit: ^limit,
        offset: ^offset,
        preload: [:actor]
      )

    query = if unread_only, do: where(query, [n], n.is_read == false), else: query

    Repo.all(query)
  end

  def unread_count(user_id) do
    from(n in Notification,
      where: n.user_id == ^user_id and n.is_read == false,
      select: count(n.id)
    )
    |> Repo.one() || 0
  end

  def mark_read(notification_id, user_id) do
    case Repo.get_by(Notification, id: notification_id, user_id: user_id) do
      nil -> {:error, :not_found}
      notification -> notification |> Notification.read_changeset() |> Repo.update()
    end
  end

  def mark_all_read(user_id) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    from(n in Notification,
      where: n.user_id == ^user_id and n.is_read == false
    )
    |> Repo.update_all(set: [is_read: true, read_at: now])
  end

  def delete_notification(notification_id, user_id) do
    case Repo.get_by(Notification, id: notification_id, user_id: user_id) do
      nil -> {:error, :not_found}
      notification -> Repo.delete(notification)
    end
  end

  def cleanup_old_notifications(days \\ 30) do
    cutoff = DateTime.utc_now() |> DateTime.add(-days * 24 * 3600, :second)

    from(n in Notification,
      where: n.inserted_at < ^cutoff and n.is_read == true
    )
    |> Repo.delete_all()
  end

  # --- Specific notification type helpers ---

  def notify_mention(user_id, actor_id, message, channel) do
    if user_id != actor_id do
      actor_name = if message.user, do: message.user.username, else: "Someone"

      attrs = %{
        type: "mention",
        title: actor_name <> " mentioned you in #" <> channel.name,
        body: String.slice(message.body, 0, 200),
        link: "/channels/" <> channel.slug,
        target_type: "message",
        target_id: message.id,
        user_id: user_id,
        actor_id: actor_id,
        metadata: %{channel_id: channel.id, channel_name: channel.name}
      }

      case create_notification(attrs) do
        {:ok, notification} ->
          broadcast_notification(notification, message.user)
          {:ok, notification}

        error ->
          error
      end
    else
      {:ok, :skipped}
    end
  end

  def notify_reply(user_id, actor_id, message, original_message) do
    if user_id != actor_id do
      channel = Repo.get(ForgeNexus.Channels.Channel, message.channel_id)
      actor_name = if message.user, do: message.user.username, else: "Someone"

      attrs = %{
        type: "reply",
        title: actor_name <> " replied to your message",
        body: String.slice(message.body, 0, 200),
        link: if(channel, do: "/channels/" <> channel.slug, else: nil),
        target_type: "message",
        target_id: message.id,
        user_id: user_id,
        actor_id: actor_id,
        metadata: %{
          channel_id: message.channel_id,
          original_message_id: original_message.id
        }
      }

      case create_notification(attrs) do
        {:ok, notification} ->
          broadcast_notification(notification, message.user)
          {:ok, notification}

        error ->
          error
      end
    else
      {:ok, :skipped}
    end
  end

  def notify_reaction(user_id, actor_id, emoji, message) do
    if user_id != actor_id do
      channel = Repo.get(ForgeNexus.Channels.Channel, message.channel_id)

      existing =
        from(n in Notification,
          where:
            n.user_id == ^user_id and
              n.actor_id == ^actor_id and
              n.type == "reaction" and
              n.target_id == ^message.id
        )
        |> Repo.one()

      if existing do
        {:ok, :already_notified}
      else
        actor = Repo.get(ForgeNexus.Accounts.User, actor_id)
        actor_name = if actor, do: actor.username, else: "Someone"

        attrs = %{
          type: "reaction",
          title: actor_name <> " reacted " <> emoji <> " to your message",
          body: String.slice(message.body, 0, 200),
          link: if(channel, do: "/channels/" <> channel.slug, else: nil),
          target_type: "message",
          target_id: message.id,
          user_id: user_id,
          actor_id: actor_id,
          metadata: %{emoji: emoji, channel_id: message.channel_id}
        }

        case create_notification(attrs) do
          {:ok, notification} ->
            broadcast_notification(notification, actor)
            {:ok, notification}

          error ->
            error
        end
      end
    else
      {:ok, :skipped}
    end
  end

  def notify_thread_moved(user_id, thread_title, thread_slug, new_forum_name, actor_id \\ nil) do
    attrs = %{
      type: "thread_moved",
      title: "Thread moved",
      body: "Your thread '#{thread_title}' was moved to #{new_forum_name}",
      link: "/threads/#{thread_slug}",
      target_type: "thread",
      user_id: user_id,
      actor_id: actor_id,
      metadata: %{new_forum_name: new_forum_name}
    }

    case create_notification(attrs) do
      {:ok, notification} ->
        broadcast_notification(notification, nil)
        {:ok, notification}

      error ->
        error
    end
  end

  def broadcast_notification(notification, actor) do
    payload = %{
      id: notification.id,
      type: notification.type,
      title: notification.title,
      body: notification.body,
      url: notification.url,
      is_read: notification.is_read,
      read_at: notification.read_at,
      metadata: notification.metadata,
      actor:
        if(actor,
          do: %{id: actor.id, username: actor.username, avatar_url: actor.avatar_url},
          else: nil
        ),
      inserted_at: notification.inserted_at
    }

    ForgeNexusWeb.Endpoint.broadcast("user:" <> notification.user_id, "new_notification", payload)
  end
end
