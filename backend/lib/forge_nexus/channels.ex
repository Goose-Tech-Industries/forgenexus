defmodule ForgeNexus.Channels do
  @moduledoc """
  The Channels context -- Discord-like multi-channel chat system.
  """
  import Ecto.Query
  alias ForgeNexus.Repo
  alias ForgeNexus.Channels.{ChannelCategory, Channel, ChannelMessage, ChannelMember, MessageReaction, ChatMention, MessageEdit, ChatThread, ThreadMessage, ThreadMember, CustomEmoji, Webhook, MessageBookmark}
  alias ForgeNexus.Accounts.{User, UserGroupMembership}
  alias ForgeNexus.Moderation

  def list_categories do
    ChannelCategory
    |> order_by(asc: :position)
    |> preload(channels: ^from(c in Channel, order_by: [asc: :position]))
    |> Repo.all()
  end

  def get_category!(id), do: Repo.get!(ChannelCategory, id)
  def create_category(attrs), do: %ChannelCategory{} |> ChannelCategory.changeset(attrs) |> Repo.insert()

  def update_category(%ChannelCategory{} = category, attrs) do
    category |> ChannelCategory.changeset(attrs) |> Repo.update()
  end

  def delete_category(id), do: get_category!(id) |> Repo.delete()

  def reorder_categories(ordered_ids) when is_list(ordered_ids) do
    Repo.transaction(fn ->
      Enum.each(Enum.with_index(ordered_ids), fn {id, index} ->
        from(c in ChannelCategory, where: c.id == ^id) |> Repo.update_all(set: [position: index])
      end)
    end)
  end

  def list_channels, do: Channel |> order_by(asc: :position) |> preload(:category) |> Repo.all()

  def list_channels_for_user(%User{} = user) do
    if Moderation.is_admin?(user.id) do
      list_channels()
    else
      query =
        case user_group_ids(user.id) do
          [] ->
            # No group memberships — only public channels are visible.
            # Skip the array-overlap fragment because Postgres can't infer
            # the array type from an empty Elixir list parameter.
            from c in Channel, where: c.is_private == false

          group_ids ->
            from c in Channel,
              where: c.is_private == false or fragment("? && ?", c.allowed_group_ids, ^group_ids)
        end

      query |> order_by(asc: :position) |> preload(:category) |> Repo.all()
    end
  end

  def get_channel(id), do: Channel |> preload(:category) |> Repo.get(id)
  def get_channel!(id), do: Channel |> preload(:category) |> Repo.get!(id)
  def get_channel_by_slug(slug), do: Channel |> where([c], c.slug == ^slug) |> preload(:category) |> Repo.one()
  def create_channel(attrs), do: %Channel{} |> Channel.changeset(attrs) |> Repo.insert()
  def update_channel(%Channel{} = ch, attrs), do: ch |> Channel.changeset(attrs) |> Repo.update()
  def delete_channel(id), do: Repo.get!(Channel, id) |> Repo.delete()

  def reorder_channels(_category_id, ordered_ids) when is_list(ordered_ids) do
    Repo.transaction(fn ->
      Enum.each(Enum.with_index(ordered_ids), fn {id, index} ->
        from(c in Channel, where: c.id == ^id) |> Repo.update_all(set: [position: index])
      end)
    end)
  end

  def archive_channel(%Channel{} = ch), do: ch |> Ecto.Changeset.change(is_archived: true) |> Repo.update()
  def unarchive_channel(%Channel{} = ch), do: ch |> Ecto.Changeset.change(is_archived: false) |> Repo.update()

  def list_messages(channel_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)
    before_id = Keyword.get(opts, :before_id)
    query =
      ChannelMessage
      |> where([m], m.channel_id == ^channel_id and m.is_deleted == false)
      |> order_by(desc: :inserted_at) |> limit(^limit)
      |> preload([:reactions, :spawned_thread, reply_to: [user: :primary_group], user: :primary_group])
    query = if before_id do
      before_msg = Repo.get(ChannelMessage, before_id)
      if before_msg do
        where(query, [m], m.inserted_at < ^before_msg.inserted_at or (m.inserted_at == ^before_msg.inserted_at and m.id < ^before_id))
      else
        query
      end
    else
      query
    end
    Repo.all(query) |> Enum.reverse()
  end

  def get_message(id), do: ChannelMessage |> preload([:reactions, :spawned_thread, reply_to: [user: :primary_group], user: :primary_group]) |> Repo.get(id)
  def get_message!(id), do: ChannelMessage |> preload([:reactions, :spawned_thread, reply_to: [user: :primary_group], user: :primary_group]) |> Repo.get!(id)

  def create_message(channel_id, user_id, attrs) do
    Repo.transaction(fn ->
      # Auto-generate link embeds if body contains URLs
      body = attrs[:body] || attrs["body"] || ""
      existing_embeds = attrs[:embeds] || attrs["embeds"] || []
      link_embeds = generate_link_embeds(body)

      message_attrs =
        attrs
        |> Map.put(:channel_id, channel_id)
        |> Map.put(:user_id, user_id)
        |> Map.put(:embeds, Enum.take(existing_embeds ++ link_embeds, 5))

      message = %ChannelMessage{} |> ChannelMessage.changeset(message_attrs) |> Repo.insert!()
      now = DateTime.utc_now() |> DateTime.truncate(:second)
      from(c in Channel, where: c.id == ^channel_id) |> Repo.update_all(inc: [message_count: 1], set: [last_message_at: now])
      message |> Repo.preload([:reactions, reply_to: [user: :primary_group], user: :primary_group])
    end)
  end

  defp generate_link_embeds(body) do
    alias ForgeNexus.Channels.LinkEmbed

    urls = LinkEmbed.extract_urls(body)

    urls
    |> Enum.take(3)
    |> Task.async_stream(fn url -> LinkEmbed.fetch_metadata(url) end, timeout: 8_000, on_timeout: :kill_task)
    |> Enum.flat_map(fn
      {:ok, %{title: nil, description: nil}} -> []
      {:ok, meta} when is_map(meta) -> [meta]
      _ -> []
    end)
  end

  def update_message(%ChannelMessage{} = message, attrs) do
    # Save edit history before updating
    if attrs[:body] || attrs["body"] do
      %MessageEdit{}
      |> MessageEdit.changeset(%{
        message_id: message.id,
        previous_body: message.body,
        edited_by_id: message.user_id
      })
      |> Repo.insert()
    end

    case message |> ChannelMessage.edit_changeset(attrs) |> Repo.update() do
      {:ok, msg} -> {:ok, Repo.preload(msg, [:reactions, reply_to: [user: :primary_group], user: :primary_group], force: true)}
      error -> error
    end
  end

  def update_message(%ChannelMessage{} = message, attrs, edited_by_id) do
    # Save edit history before updating
    if attrs[:body] || attrs["body"] do
      %MessageEdit{}
      |> MessageEdit.changeset(%{
        message_id: message.id,
        previous_body: message.body,
        edited_by_id: edited_by_id
      })
      |> Repo.insert()
    end

    case message |> ChannelMessage.edit_changeset(attrs) |> Repo.update() do
      {:ok, msg} -> {:ok, Repo.preload(msg, [:reactions, reply_to: [user: :primary_group], user: :primary_group], force: true)}
      error -> error
    end
  end

  def delete_message(%ChannelMessage{} = message, deleted_by_id) do
    message |> ChannelMessage.delete_changeset(deleted_by_id) |> Repo.update()
  end

  def hard_delete_message(id) do
    message = Repo.get!(ChannelMessage, id)
    channel_id = message.channel_id
    case Repo.delete(message) do
      {:ok, _} ->
        from(c in Channel, where: c.id == ^channel_id) |> Repo.update_all(inc: [message_count: -1])
        {:ok, message}
      error -> error
    end
  end

  def pin_message(%ChannelMessage{} = msg, pinned_by_id), do: msg |> ChannelMessage.pin_changeset(pinned_by_id) |> Repo.update()
  def unpin_message(%ChannelMessage{} = msg), do: msg |> ChannelMessage.unpin_changeset() |> Repo.update()

  def get_pinned_messages(channel_id) do
    ChannelMessage
    |> where([m], m.channel_id == ^channel_id and m.is_pinned == true)
    |> order_by(desc: :pinned_at)
    |> preload([:reactions, :spawned_thread, reply_to: [user: :primary_group], user: :primary_group])
    |> Repo.all()
  end

  def get_or_create_member(channel_id, user_id) do
    case Repo.get_by(ChannelMember, channel_id: channel_id, user_id: user_id) do
      nil -> %ChannelMember{} |> ChannelMember.changeset(%{channel_id: channel_id, user_id: user_id}) |> Repo.insert()
      member -> {:ok, member}
    end
  end

  def mark_read(channel_id, user_id, message_id) do
    {:ok, member} = get_or_create_member(channel_id, user_id)
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    member |> Ecto.Changeset.change(last_read_at: now, last_read_message_id: message_id) |> Repo.update()
  end

  def get_unread_counts(user_id) do
    members = ChannelMember |> where([m], m.user_id == ^user_id) |> Repo.all()
    members |> Enum.map(fn member ->
      count_query = ChannelMessage |> where([m], m.channel_id == ^member.channel_id and m.is_deleted == false)
      count_query = if member.last_read_at, do: where(count_query, [m], m.inserted_at > ^member.last_read_at), else: count_query
      {member.channel_id, Repo.aggregate(count_query, :count)}
    end) |> Map.new()
  end

  def set_notification_level(channel_id, user_id, level) do
    {:ok, member} = get_or_create_member(channel_id, user_id)
    member |> ChannelMember.changeset(%{notification_level: level}) |> Repo.update()
  end

  def mute_channel(channel_id, user_id) do
    {:ok, member} = get_or_create_member(channel_id, user_id)
    member |> Ecto.Changeset.change(is_muted: true) |> Repo.update()
  end

  def unmute_channel(channel_id, user_id) do
    {:ok, member} = get_or_create_member(channel_id, user_id)
    member |> Ecto.Changeset.change(is_muted: false) |> Repo.update()
  end

  def add_reaction(message_id, user_id, emoji) do
    %MessageReaction{} |> MessageReaction.changeset(%{message_id: message_id, user_id: user_id, emoji: emoji}) |> Repo.insert()
  end

  def remove_reaction(message_id, user_id, emoji) do
    case Repo.get_by(MessageReaction, message_id: message_id, user_id: user_id, emoji: emoji) do
      nil -> {:error, :not_found}
      reaction -> Repo.delete(reaction)
    end
  end

  def get_reactions(message_id) do
    reactions = MessageReaction |> where([r], r.message_id == ^message_id) |> preload(:user) |> Repo.all()
    reactions
    |> Enum.group_by(fn r -> r.emoji end)
    |> Enum.map(fn {emoji, group} ->
      %{emoji: emoji, count: length(group), users: Enum.map(group, fn r -> %{id: r.user.id, username: r.user.username} end)}
    end)
  end

  def can_view_channel?(%User{} = user, %Channel{} = channel) do
    cond do
      Moderation.is_admin?(user.id) -> true
      not channel.is_private -> true
      true -> Enum.any?(channel.allowed_group_ids, fn gid -> gid in user_group_ids(user.id) end)
    end
  end

  def can_post_in_channel?(%User{} = user, %Channel{} = channel) do
    cond do
      channel.is_archived -> Moderation.is_admin?(user.id)
      channel.is_read_only -> Moderation.is_admin?(user.id) or Moderation.is_staff?(user.id)
      not can_view_channel?(user, channel) -> false
      true -> true
    end
  end

  @doc """
  Checks slowmode cooldown. Returns :ok or {:error, seconds_remaining}.
  Staff/admins bypass slowmode.
  """
  def check_slowmode(%Channel{} = channel, %User{} = user) do
    cond do
      channel.slowmode_seconds == 0 -> :ok
      Moderation.is_staff?(user.id) -> :ok
      true ->
        last_msg =
          ChannelMessage
          |> where([m], m.channel_id == ^channel.id and m.user_id == ^user.id and m.is_deleted == false)
          |> order_by(desc: :inserted_at)
          |> limit(1)
          |> Repo.one()

        case last_msg do
          nil -> :ok
          msg ->
            elapsed = DateTime.diff(DateTime.utc_now(), msg.inserted_at, :second)
            remaining = channel.slowmode_seconds - elapsed

            if remaining > 0 do
              {:error, remaining}
            else
              :ok
            end
        end
    end
  end

  def seed_defaults do
    staff_group_ids = from(g in ForgeNexus.Accounts.UserGroup, where: g.is_staff == true, select: g.id) |> Repo.all()
    Repo.transaction(fn ->
      {:ok, general_cat} = create_category(%{name: "General", position: 0})
      create_channel(%{name: "general", slug: "general", description: "General discussion", topic: "Welcome to the community!", position: 0, category_id: general_cat.id})
      create_channel(%{name: "introductions", slug: "introductions", description: "Introduce yourself to the community", position: 1, category_id: general_cat.id})
      create_channel(%{name: "off-topic", slug: "off-topic", description: "Anything goes", position: 2, category_id: general_cat.id})
      {:ok, community_cat} = create_category(%{name: "Community", position: 1})
      create_channel(%{name: "announcements", slug: "announcements", description: "Official announcements", topic: "Important updates from the team", position: 0, category_id: community_cat.id, is_read_only: true, type: "announcements"})
      create_channel(%{name: "feedback", slug: "feedback", description: "Share your feedback and suggestions", position: 1, category_id: community_cat.id})
      create_channel(%{name: "help", slug: "help", description: "Need help? Ask here", position: 2, category_id: community_cat.id})
      {:ok, staff_cat} = create_category(%{name: "Staff", position: 2})
      create_channel(%{name: "staff-chat", slug: "staff-chat", description: "Staff-only discussion", position: 0, category_id: staff_cat.id, is_private: true, allowed_group_ids: staff_group_ids})
      create_channel(%{name: "mod-log", slug: "mod-log", description: "Moderation action log", position: 1, category_id: staff_cat.id, is_private: true, is_read_only: true, allowed_group_ids: staff_group_ids})
    end)
  end

  # --- Threads ---

  def create_thread(channel_id, parent_message_id, user_id, name) do
    Repo.transaction(fn ->
      thread =
        %ChatThread{}
        |> ChatThread.changeset(%{
          name: name,
          channel_id: channel_id,
          parent_message_id: parent_message_id,
          created_by_id: user_id
        })
        |> Repo.insert!()

      # Link parent message to thread
      from(m in ChannelMessage, where: m.id == ^parent_message_id)
      |> Repo.update_all(set: [thread_id: thread.id])

      # Auto-join the creator
      %ThreadMember{}
      |> ThreadMember.changeset(%{thread_id: thread.id, user_id: user_id})
      |> Repo.insert!()

      thread |> Repo.preload([:created_by, :parent_message, :channel])
    end)
  end

  def get_thread(id) do
    ChatThread
    |> preload([:created_by, :channel, parent_message: [user: :primary_group]])
    |> Repo.get(id)
  end

  def list_threads(channel_id) do
    ChatThread
    |> where([t], t.channel_id == ^channel_id and t.is_archived == false)
    |> order_by(desc: :last_message_at)
    |> preload([:created_by])
    |> Repo.all()
  end

  def list_thread_messages(thread_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)
    before_id = Keyword.get(opts, :before_id)

    query =
      ThreadMessage
      |> where([m], m.thread_id == ^thread_id and m.is_deleted == false)
      |> order_by(desc: :inserted_at)
      |> limit(^limit)
      |> preload(user: :primary_group)

    query =
      if before_id do
        before_msg = Repo.get(ThreadMessage, before_id)
        if before_msg do
          where(query, [m], m.inserted_at < ^before_msg.inserted_at)
        else
          query
        end
      else
        query
      end

    Repo.all(query) |> Enum.reverse()
  end

  def create_thread_message(thread_id, user_id, body) do
    Repo.transaction(fn ->
      msg =
        %ThreadMessage{}
        |> ThreadMessage.changeset(%{body: body, thread_id: thread_id, user_id: user_id})
        |> Repo.insert!()

      now = DateTime.utc_now() |> DateTime.truncate(:second)
      from(t in ChatThread, where: t.id == ^thread_id)
      |> Repo.update_all(inc: [message_count: 1], set: [last_message_at: now])

      # Auto-join thread if not already member
      case Repo.get_by(ThreadMember, thread_id: thread_id, user_id: user_id) do
        nil ->
          %ThreadMember{}
          |> ThreadMember.changeset(%{thread_id: thread_id, user_id: user_id})
          |> Repo.insert()
        _ -> :ok
      end

      msg |> Repo.preload(user: :primary_group)
    end)
  end

  def archive_thread(thread_id) do
    Repo.get!(ChatThread, thread_id)
    |> Ecto.Changeset.change(is_archived: true)
    |> Repo.update()
  end

  def lock_thread_chat(thread_id) do
    Repo.get!(ChatThread, thread_id)
    |> Ecto.Changeset.change(is_locked: true)
    |> Repo.update()
  end

  # --- Bookmarks ---

  def list_bookmarks(user_id) do
    MessageBookmark
    |> where([b], b.user_id == ^user_id)
    |> order_by(desc: :inserted_at)
    |> preload(message: [:reactions, :spawned_thread, channel: [], reply_to: [user: :primary_group], user: :primary_group])
    |> Repo.all()
  end

  def toggle_bookmark(message_id, user_id, note \\ nil) do
    case Repo.get_by(MessageBookmark, message_id: message_id, user_id: user_id) do
      nil ->
        %MessageBookmark{}
        |> MessageBookmark.changeset(%{message_id: message_id, user_id: user_id, note: note})
        |> Repo.insert()

      existing ->
        Repo.delete(existing)
    end
  end

  def is_bookmarked?(message_id, user_id) do
    MessageBookmark
    |> where([b], b.message_id == ^message_id and b.user_id == ^user_id)
    |> Repo.exists?()
  end

  def get_bookmark_ids(user_id) do
    MessageBookmark
    |> where([b], b.user_id == ^user_id)
    |> select([b], b.message_id)
    |> Repo.all()
    |> MapSet.new()
  end

  # --- Webhooks ---

  def list_webhooks(channel_id) do
    Webhook
    |> where([w], w.channel_id == ^channel_id)
    |> order_by(asc: :name)
    |> preload(:channel)
    |> Repo.all()
  end

  def get_webhook_by_token(token) do
    Webhook
    |> where([w], w.token == ^token and w.is_active == true)
    |> preload(:channel)
    |> Repo.one()
  end

  def get_webhook!(id), do: Repo.get!(Webhook, id) |> Repo.preload(:channel)

  def create_webhook(attrs) do
    %Webhook{} |> Webhook.changeset(attrs) |> Repo.insert()
  end

  def update_webhook(id, attrs) do
    get_webhook!(id) |> Webhook.changeset(attrs) |> Repo.update()
  end

  def delete_webhook(id) do
    get_webhook!(id) |> Repo.delete()
  end

  def regenerate_webhook_token(id) do
    webhook = get_webhook!(id)
    new_token = :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
    webhook |> Ecto.Changeset.change(token: new_token) |> Repo.update()
  end

  @doc """
  Execute a webhook — creates a message in the channel with the webhook's identity.
  """
  def execute_webhook(%Webhook{} = webhook, body, username \\ nil, avatar_url \\ nil) do
    # Create a system-like message with webhook identity in embeds
    webhook_meta = %{
      "type" => "webhook",
      "webhook_name" => username || webhook.name,
      "webhook_avatar" => avatar_url || webhook.avatar_url
    }

    attrs = %{
      body: body,
      channel_id: webhook.channel_id,
      embeds: [webhook_meta]
    }

    # Use a system user ID or nil for webhook messages
    # For now, store with nil user_id — the webhook embed carries the identity
    message_attrs = Map.put(attrs, :user_id, webhook.created_by_id)
    message = %ChannelMessage{} |> ChannelMessage.changeset(message_attrs) |> Repo.insert!()
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    from(c in Channel, where: c.id == ^webhook.channel_id) |> Repo.update_all(inc: [message_count: 1], set: [last_message_at: now])
    {:ok, message |> Repo.preload([:reactions, reply_to: [user: :primary_group], user: :primary_group])}
  end

  # --- Custom Emojis ---

  def list_custom_emojis do
    CustomEmoji
    |> where([e], e.is_active == true)
    |> order_by(asc: :category, asc: :name)
    |> Repo.all()
  end

  def list_all_custom_emojis do
    CustomEmoji |> order_by(asc: :category, asc: :name) |> Repo.all()
  end

  def get_custom_emoji!(id), do: Repo.get!(CustomEmoji, id)

  def create_custom_emoji(attrs) do
    %CustomEmoji{} |> CustomEmoji.changeset(attrs) |> Repo.insert()
  end

  def update_custom_emoji(id, attrs) do
    get_custom_emoji!(id) |> CustomEmoji.changeset(attrs) |> Repo.update()
  end

  def delete_custom_emoji(id) do
    get_custom_emoji!(id) |> Repo.delete()
  end

  # --- Message Search ---

  def search_messages(user, query, opts \\ []) do
    channel_slug = Keyword.get(opts, :channel)
    user_id_filter = Keyword.get(opts, :user_id)
    has_filter = Keyword.get(opts, :has)
    limit = Keyword.get(opts, :limit, 25)
    offset = Keyword.get(opts, :offset, 0)

    # Start with base query
    base =
      ChannelMessage
      |> where([m], m.is_deleted == false)
      |> where([m], ilike(m.body, ^"%#{sanitize_like(query)}%"))
      |> order_by(desc: :inserted_at)
      |> limit(^limit)
      |> offset(^offset)
      |> preload([:reactions, channel: [], reply_to: [user: :primary_group], user: :primary_group])

    # Filter by channel slug
    base =
      if channel_slug do
        base
        |> join(:inner, [m], c in Channel, on: m.channel_id == c.id)
        |> where([m, c], c.slug == ^channel_slug)
      else
        base
      end

    # Filter by user
    base = if user_id_filter, do: where(base, [m], m.user_id == ^user_id_filter), else: base

    # Filter by special attributes
    base =
      case has_filter do
        "pinned" -> where(base, [m], m.is_pinned == true)
        "attachment" -> where(base, [m], fragment("array_length(?, 1) > 0", m.attachments))
        _ -> base
      end

    results = Repo.all(base)

    # Filter out messages from channels the user can't view
    Enum.filter(results, fn msg ->
      channel = msg.channel || get_channel(msg.channel_id)
      channel && can_view_channel?(user, channel)
    end)
  end

  defp sanitize_like(str) do
    str
    |> String.replace("\\", "\\\\")
    |> String.replace("%", "\\%")
    |> String.replace("_", "\\_")
  end

  # --- @Mentions System ---

  def extract_and_create_mentions(message) do
    body = message.body

    # Find @username mentions
    user_mentions =
      Regex.scan(~r/@(\w+)/, body)
      |> Enum.map(fn [_, username] -> username end)
      |> Enum.reject(fn u -> u in ["everyone", "here"] end)
      |> Enum.uniq()

    # Look up users by username
    users =
      from(u in User, where: u.username in ^user_mentions, select: {u.username, u.id})
      |> Repo.all()
      |> Map.new()

    # Create mention records for found users
    mentions =
      Enum.flat_map(users, fn {_username, user_id} ->
        case Repo.insert(
               %ChatMention{message_id: message.id, mentioned_user_id: user_id, mention_type: "user"},
               on_conflict: :nothing
             ) do
          {:ok, m} -> [m]
          _ -> []
        end
      end)

    # Check for @everyone and @here
    if String.contains?(body, "@everyone") or String.contains?(body, "@here") do
      member_ids =
        from(cm in ChannelMember, where: cm.channel_id == ^message.channel_id, select: cm.user_id)
        |> Repo.all()

      type = if String.contains?(body, "@everyone"), do: "everyone", else: "here"

      Enum.each(member_ids, fn uid ->
        Repo.insert(
          %ChatMention{message_id: message.id, mentioned_user_id: uid, mention_type: type},
          on_conflict: :nothing
        )
      end)
    end

    mentions
  end

  def get_unread_mentions(user_id) do
    from(m in ChatMention,
      where: m.mentioned_user_id == ^user_id and m.read == false,
      join: msg in assoc(m, :message),
      join: ch in assoc(msg, :channel),
      preload: [message: {msg, channel: ch}],
      order_by: [desc: m.inserted_at],
      limit: 50
    )
    |> Repo.all()
  end

  def mark_mentions_read(user_id, channel_id) do
    from(m in ChatMention,
      where: m.mentioned_user_id == ^user_id and m.read == false,
      join: msg in assoc(m, :message),
      where: msg.channel_id == ^channel_id
    )
    |> Repo.update_all(set: [read: true])
  end

  def unread_mention_counts(user_id) do
    from(m in ChatMention,
      where: m.mentioned_user_id == ^user_id and m.read == false,
      join: msg in assoc(m, :message),
      group_by: msg.channel_id,
      select: {msg.channel_id, count(m.id)}
    )
    |> Repo.all()
    |> Map.new()
  end

  # --- Message Edit History ---

  def get_message_edits(message_id) do
    from(e in MessageEdit,
      where: e.message_id == ^message_id,
      order_by: [desc: e.inserted_at],
      preload: [:edited_by]
    )
    |> Repo.all()
  end

    defp user_group_ids(user_id) do
    from(m in UserGroupMembership, where: m.user_id == ^user_id, select: m.group_id) |> Repo.all()
  end
end
