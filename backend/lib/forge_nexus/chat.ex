defmodule ForgeNexus.Chat do
  @moduledoc """
  The Chat context — conversations, messages, friendships, notifications.
  """
  import Ecto.Query
  alias ForgeNexus.Repo

  alias ForgeNexus.Chat.{
    Conversation,
    ConversationParticipant,
    Message,
    Friendship,
    Notification,
    ShoutboxMessage
  }

  # --- Conversations ---

  def list_conversations(user_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 25)

    conversation_ids =
      from(cp in ConversationParticipant,
        where: cp.user_id == ^user_id,
        select: cp.conversation_id
      )
      |> Repo.all()

    Conversation
    |> where([c], c.id in ^conversation_ids)
    |> order_by(desc: :last_message_at)
    |> limit(^limit)
    |> preload(participants: :user)
    |> Repo.all()
  end

  def get_or_create_direct_conversation(user_id, other_user_id) do
    # Find existing direct conversation between these two users
    existing =
      from(c in Conversation,
        where: c.type == "direct",
        join: cp1 in ConversationParticipant,
        on: cp1.conversation_id == c.id and cp1.user_id == ^user_id,
        join: cp2 in ConversationParticipant,
        on: cp2.conversation_id == c.id and cp2.user_id == ^other_user_id,
        limit: 1
      )
      |> Repo.one()

    case existing do
      nil -> create_direct_conversation(user_id, other_user_id)
      conversation -> {:ok, conversation}
    end
  end

  defp create_direct_conversation(user_id, other_user_id) do
    Repo.transaction(fn ->
      conversation =
        %Conversation{}
        |> Conversation.changeset(%{type: "direct", creator_id: user_id})
        |> Repo.insert!()

      now = DateTime.utc_now() |> DateTime.truncate(:second)

      for uid <- [user_id, other_user_id] do
        %ConversationParticipant{}
        |> ConversationParticipant.changeset(%{conversation_id: conversation.id, user_id: uid})
        |> Ecto.Changeset.put_change(:joined_at, now)
        |> Repo.insert!()
      end

      conversation
    end)
  end

  def user_in_conversation?(user_id, conversation_id) do
    Repo.exists?(
      from p in ConversationParticipant,
        where: p.user_id == ^user_id and p.conversation_id == ^conversation_id
    )
  end

  def create_group_conversation(creator_id, title, participant_ids) do
    Repo.transaction(fn ->
      conversation =
        %Conversation{}
        |> Conversation.changeset(%{type: "group", title: title, creator_id: creator_id})
        |> Repo.insert!()

      now = DateTime.utc_now() |> DateTime.truncate(:second)

      for uid <- [creator_id | participant_ids] |> Enum.uniq() do
        role = if uid == creator_id, do: "admin", else: "member"

        %ConversationParticipant{}
        |> ConversationParticipant.changeset(%{
          conversation_id: conversation.id,
          user_id: uid,
          role: role
        })
        |> Ecto.Changeset.put_change(:joined_at, now)
        |> Repo.insert!()
      end

      conversation |> Repo.preload(participants: :user)
    end)
  end

  # --- Messages ---

  def list_messages(conversation_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)
    before = Keyword.get(opts, :before)

    query =
      Message
      |> where([m], m.conversation_id == ^conversation_id)
      |> order_by(desc: :inserted_at)
      |> limit(^limit)
      |> preload(:user)

    query =
      if before do
        where(query, [m], m.inserted_at < ^before)
      else
        query
      end

    Repo.all(query) |> Enum.reverse()
  end

  def send_message(attrs) do
    Repo.transaction(fn ->
      message =
        %Message{}
        |> Message.changeset(attrs)
        |> Repo.insert!()

      # Update conversation
      now = DateTime.utc_now() |> DateTime.truncate(:second)
      conversation_id = attrs[:conversation_id] || attrs["conversation_id"]

      from(c in Conversation, where: c.id == ^conversation_id)
      |> Repo.update_all(inc: [message_count: 1], set: [last_message_at: now])

      message |> Repo.preload(:user)
    end)
  end

  # --- Message actions ---

  def edit_message(message_id, user_id, new_body) do
    case Repo.get(Message, message_id) do
      nil ->
        {:error, :not_found}

      %Message{user_id: ^user_id} = message ->
        message
        |> Ecto.Changeset.change(
          body: new_body,
          is_edited: true,
          edited_at: DateTime.utc_now() |> DateTime.truncate(:second)
        )
        |> Repo.update()

      _ ->
        {:error, :unauthorized}
    end
  end

  def delete_message(message_id, user_id) do
    case Repo.get(Message, message_id) do
      nil ->
        {:error, :not_found}

      %Message{user_id: ^user_id} = message ->
        message
        |> Ecto.Changeset.change(is_deleted: true)
        |> Repo.update()

      _ ->
        {:error, :unauthorized}
    end
  end

  def mark_conversation_read(conversation_id, user_id, _message_id) do
    import Ecto.Query

    from(p in ForgeNexus.Chat.ConversationParticipant,
      where: p.conversation_id == ^conversation_id and p.user_id == ^user_id
    )
    |> Repo.update_all(set: [last_read_at: DateTime.utc_now() |> DateTime.truncate(:second)])

    :ok
  end

  def add_reaction(message_id, user_id, emoji) do
    # Store as a simple map on the message for DMs (lightweight approach)
    case Repo.get(Message, message_id) do
      nil ->
        {:error, :not_found}

      message ->
        reactions = message.reactions || %{}
        entry = reactions[emoji] || %{"count" => 0, "users" => []}
        users = entry["users"] || []

        unless user_id in users do
          updated =
            Map.put(reactions, emoji, %{
              "count" => length(users) + 1,
              "users" => users ++ [user_id]
            })

          message
          |> Ecto.Changeset.change(reactions: updated)
          |> Repo.update()
          |> case do
            {:ok, msg} -> {:ok, msg.reactions}
            err -> err
          end
        else
          {:ok, reactions}
        end
    end
  end

  def remove_reaction(message_id, user_id, emoji) do
    case Repo.get(Message, message_id) do
      nil ->
        {:error, :not_found}

      message ->
        reactions = message.reactions || %{}
        entry = reactions[emoji] || %{"count" => 0, "users" => []}
        users = (entry["users"] || []) -- [user_id]

        updated =
          if length(users) == 0 do
            Map.delete(reactions, emoji)
          else
            Map.put(reactions, emoji, %{"count" => length(users), "users" => users})
          end

        message
        |> Ecto.Changeset.change(reactions: updated)
        |> Repo.update()
        |> case do
          {:ok, msg} -> {:ok, msg.reactions}
          err -> err
        end
    end
  end

  # --- Friendships ---

  def send_friend_request(user_id, friend_id) do
    %Friendship{}
    |> Friendship.changeset(%{user_id: user_id, friend_id: friend_id, status: "pending"})
    |> Repo.insert()
  end

  def accept_friend_request(friendship) do
    friendship
    |> Ecto.Changeset.change(status: "accepted")
    |> Repo.update()
  end

  def list_friends(user_id) do
    from(f in Friendship,
      where: (f.user_id == ^user_id or f.friend_id == ^user_id) and f.status == "accepted",
      preload: [:user, :friend]
    )
    |> Repo.all()
    |> Enum.map(fn f ->
      if f.user_id == user_id, do: f.friend, else: f.user
    end)
  end

  def pending_friend_requests(user_id) do
    from(f in Friendship,
      where: f.friend_id == ^user_id and f.status == "pending",
      preload: :user
    )
    |> Repo.all()
  end

  def get_friendship(id), do: Repo.get(Friendship, id)

  @doc "Find the friendship row between two users, if any (direction-agnostic)."
  def friendship_between(user_a, user_b) do
    from(f in Friendship,
      where:
        (f.user_id == ^user_a and f.friend_id == ^user_b) or
          (f.user_id == ^user_b and f.friend_id == ^user_a),
      limit: 1
    )
    |> Repo.one()
  end

  def decline_friend_request(friendship) do
    friendship
    |> Ecto.Changeset.change(status: "declined")
    |> Repo.update()
  end

  def remove_friendship(friendship), do: Repo.delete(friendship)

  @doc """
  Returns the relationship status between viewer and target from viewer's POV.
  Used to render Add Friend / Accept / Cancel / Friends buttons.
  """
  def friendship_status(viewer_id, target_id) do
    case friendship_between(viewer_id, target_id) do
      nil ->
        %{status: "none"}

      %Friendship{status: "accepted"} = f ->
        %{status: "friends", id: f.id}

      %Friendship{status: "pending", user_id: user_id} = f ->
        if user_id == viewer_id,
          do: %{status: "request_sent", id: f.id},
          else: %{status: "request_received", id: f.id}

      %Friendship{status: "declined", id: id} ->
        %{status: "declined", id: id}
    end
  end

  # --- Notifications ---

  def list_notifications(user_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 25)

    Notification
    |> where([n], n.user_id == ^user_id)
    |> order_by(desc: :inserted_at)
    |> limit(^limit)
    |> preload(:actor)
    |> Repo.all()
  end

  def unread_count(user_id) do
    from(n in Notification, where: n.user_id == ^user_id and n.is_read == false)
    |> Repo.aggregate(:count)
  end

  def mark_notification_read(notification) do
    notification |> Notification.read_changeset() |> Repo.update()
  end

  def mark_all_read(user_id) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    from(n in Notification, where: n.user_id == ^user_id and n.is_read == false)
    |> Repo.update_all(set: [is_read: true, read_at: now])
  end

  # --- Shoutbox ---

  def send_shoutbox_message(user_id, body) do
    %ShoutboxMessage{}
    |> ShoutboxMessage.changeset(%{user_id: user_id, body: body})
    |> Repo.insert()
  end

  def send_system_shout(body) do
    # System messages use nil user — need a system user or skip user_id validation
    # For now, require a user_id even for system shouts
    %ShoutboxMessage{}
    |> ShoutboxMessage.changeset(%{body: body, is_system: true, user_id: nil})
    |> Repo.insert()
  end

  def get_shoutbox_messages(opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)

    ShoutboxMessage
    |> where([m], m.is_deleted == false)
    |> order_by(desc: :inserted_at)
    |> limit(^limit)
    |> preload(user: :primary_group)
    |> Repo.all()
    |> Enum.reverse()
  end

  def get_pinned_shouts do
    ShoutboxMessage
    |> where([m], m.is_pinned == true and m.is_deleted == false)
    |> order_by(desc: :inserted_at)
    |> preload(user: :primary_group)
    |> Repo.all()
  end

  def pin_shout(message_id) do
    case Repo.get(ShoutboxMessage, message_id) do
      nil -> {:error, :not_found}
      msg -> msg |> ShoutboxMessage.changeset(%{is_pinned: true}) |> Repo.update()
    end
  end

  def unpin_shout(message_id) do
    case Repo.get(ShoutboxMessage, message_id) do
      nil -> {:error, :not_found}
      msg -> msg |> ShoutboxMessage.changeset(%{is_pinned: false}) |> Repo.update()
    end
  end

  def delete_shout(message_id) do
    case Repo.get(ShoutboxMessage, message_id) do
      nil -> {:error, :not_found}
      msg -> msg |> ShoutboxMessage.changeset(%{is_deleted: true}) |> Repo.update()
    end
  end

  def clear_shoutbox do
    {count, _} =
      from(m in ShoutboxMessage, where: m.is_deleted == false)
      |> Repo.update_all(set: [is_deleted: true])

    {:ok, count}
  end

  def shoutbox_stats do
    total = Repo.one(from m in ShoutboxMessage, where: m.is_deleted == false, select: count(m.id))

    today =
      Repo.one(
        from m in ShoutboxMessage,
          where:
            m.is_deleted == false and
              m.inserted_at >=
                ^(DateTime.utc_now() |> DateTime.to_date() |> DateTime.new!(~T[00:00:00])),
          select: count(m.id)
      )

    pinned =
      Repo.one(
        from m in ShoutboxMessage,
          where: m.is_pinned == true and m.is_deleted == false,
          select: count(m.id)
      )

    %{total_messages: total, messages_today: today || 0, pinned_count: pinned}
  end
end
