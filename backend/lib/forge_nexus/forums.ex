defmodule ForgeNexus.Forums do
  @moduledoc """
  The Forums context — categories, forums, threads, posts, polls.
  """
  import Ecto.Query
  alias ForgeNexus.Repo
  alias ForgeNexus.Forums.{Category, Forum, Thread, Post, Poll, PollOption, Badge, UserBadge, ThreadPrefix, PostDraft, PostRating, ContentIgnore, ThreadRating, ThreadRead, ThreadSubscription, PostBookmark, ReputationEvent, CustomBBCode, ForumWebhook, ForumPermission, ThreadParticipant, PostEdit}
  alias ForgeNexus.Moderation.Reaction
  alias ForgeNexus.{Accounts, Notifications, Search}
  alias ForgeNexus.Workers.NotificationEmailer
  alias ForgeNexus.ContentFilter

  # --- Categories ---

  def list_categories do
    Category
    |> where([c], is_nil(c.parent_id) and c.is_visible == true)
    |> order_by(:position)
    |> preload(forums: ^forums_query())
    |> Repo.all()
  end

  def get_category!(id), do: Repo.get!(Category, id)

  def get_category_by_slug!(slug), do: Repo.get_by!(Category, slug: slug)

  def create_category(attrs) do
    %Category{}
    |> Category.changeset(attrs)
    |> Repo.insert()
  end

  # --- Forums ---

  defp forums_query do
    children_query =
      from c in Forum,
        where: c.is_visible == true,
        order_by: c.position,
        preload: [:last_post_user]

    from f in Forum,
      where: f.is_visible == true and is_nil(f.parent_id),
      order_by: f.position,
      preload: [:last_post_user, children: ^children_query]
  end

  def get_forum!(id), do: Repo.get!(Forum, id)

  def get_forum_by_slug(slug) do
    Repo.get_by(Forum, slug: slug)
  end

  def get_forum_by_slug!(slug) do
    children_query =
      from c in Forum,
        where: c.is_visible == true,
        order_by: c.position,
        preload: [:last_post_user]

    Forum
    |> Repo.get_by!(slug: slug)
    |> Repo.preload([:category, :parent, children: children_query])
  end

  def create_forum(attrs) do
    %Forum{}
    |> Forum.changeset(attrs)
    |> Repo.insert()
  end

  # --- Threads ---

  def list_threads(forum_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 25)
    offset = Keyword.get(opts, :offset, 0)
    sort = Keyword.get(opts, :sort, "newest")
    prefix = Keyword.get(opts, :prefix)
    include_hidden = Keyword.get(opts, :include_hidden, false)

    query =
      if include_hidden do
        Thread |> where([t], t.forum_id == ^forum_id)
      else
        Thread |> where([t], t.forum_id == ^forum_id and t.is_hidden == false)
      end

    # Apply prefix filter
    query = if prefix && prefix != "" do
      where(query, [t], t.prefix == ^prefix)
    else
      query
    end

    # Apply sort (pinned threads always first)
    query = case sort do
      "most_replies" -> order_by(query, [t], [desc: t.is_pinned, desc: t.reply_count])
      "most_views" -> order_by(query, [t], [desc: t.is_pinned, desc: t.view_count])
      "oldest" -> order_by(query, [t], [desc: t.is_pinned, asc: t.inserted_at])
      _ -> order_by(query, [t], [desc: t.is_pinned, desc: t.last_post_at])
    end

    query
    |> limit(^limit)
    |> offset(^offset)
    |> preload([:user, :last_post_user])
    |> Repo.all()
  end

  def get_thread!(id) do
    Thread
    |> Repo.get!(id)
    |> Repo.preload([:user, :forum, :poll])
  end

  def get_thread_by_slug!(slug) do
    Thread
    |> Repo.get_by!(slug: slug)
    |> Repo.preload([:user, :forum, :poll])
  end

  def create_thread(attrs) do
    body = attrs["body"] || attrs[:body] || ""
    user_id = attrs["user_id"] || attrs[:user_id]

    case ContentFilter.check(body, user_id) do
      {:ok, :clean} ->
        do_create_thread(attrs)

      {:error, reason} ->
        {:error, :spam_detected, reason}
    end
  end

  defp do_create_thread(attrs) do
    Repo.transaction(fn ->
      thread =
        %Thread{}
        |> Thread.changeset(attrs)
        |> Repo.insert!()

      # Create the first post — auto-convert BBCode to HTML if the caller
      # didn't ship pre-rendered HTML. The frontend submits body only.
      body = attrs["body"] || attrs[:body]
      body_html =
        case attrs["body_html"] || attrs[:body_html] do
          nil -> if body, do: ForgeNexus.BBCode.to_html(body), else: nil
          "" -> if body, do: ForgeNexus.BBCode.to_html(body), else: ""
          html -> html
        end

      first_post =
        %Post{}
        |> Post.changeset(%{
          body: body,
          body_html: body_html,
          thread_id: thread.id,
          user_id: thread.user_id,
          is_first_post: true,
          ip_address: attrs["ip_address"] || attrs[:ip_address]
      })
      |> Repo.insert!()

      # Update forum counters: thread_count + post_count (OP counts as a post).
      # Track it as the latest post too so forum listings don't lag behind.
      now = DateTime.utc_now() |> DateTime.truncate(:second)
      from(f in Forum, where: f.id == ^thread.forum_id)
      |> Repo.update_all(
        inc: [thread_count: 1, post_count: 1],
        set: [last_post_at: now, last_post_user_id: thread.user_id]
      )

      # Forum-index counters refresh broadcast happens AFTER the transaction
      # commits — see the case clause at the bottom of this function.

      # Mirror onto the thread itself so reply_count = posts - 1 stays correct
      # without waiting on the reconciler.
      from(t in Thread, where: t.id == ^thread.id)
      |> Repo.update_all(set: [last_post_at: now, last_post_user_id: thread.user_id])

      # Update user counter: thread_count + post_count for the OP
      from(u in ForgeNexus.Accounts.User, where: u.id == ^thread.user_id)
      |> Repo.update_all(inc: [thread_count: 1, post_count: 1], set: [last_post_at: now])

      # Extract thumbnail from first post body
      body = attrs["body"] || attrs[:body] || ""
      thumbnail_url = extract_first_image(body)
      thread = if thumbnail_url do
        thread
        |> Ecto.Changeset.change(thumbnail_url: thumbnail_url)
        |> Repo.update!()
      else
        thread
      end

      # Index in search (async, don't fail transaction)
      Task.start(fn -> Search.index_thread(thread) end)

      # Process @mentions in the first post and notify mentioned users
      Task.start(fn -> process_mentions(first_post, thread.user_id) end)
      # Process [quote=author] references the same way
      Task.start(fn -> process_quotes(first_post, thread.user_id) end)

      # Log reputation event for thread creation (only for published threads)
      if thread.status == "published" do
        Task.start(fn -> log_reputation_event(thread.user_id, "thread_created", 2, "thread", thread.id) end)
      end

      {thread, now}
    end)
    |> case do
      {:ok, {thread, now}} ->
        # Broadcast counters AFTER transaction commits.
        Task.start(fn ->
          ForgeNexusWeb.Endpoint.broadcast("forums:index", "forum_updated", %{
            forum_id: thread.forum_id,
            delta: %{thread_count: 1, post_count: 1},
            last_post_at: now,
            last_post_user_id: thread.user_id
          })
        end)
        {:ok, thread}

      other ->
        other
    end
  end

  defp extract_first_image(body) do
    cond do
      # BBCode [img] tag
      match = Regex.run(~r/\[img\](https?:\/\/[^\[]+)\[\/img\]/i, body) ->
        Enum.at(match, 1)
      # HTML <img src="..."> tag
      match = Regex.run(~r/<img[^>]+src=["'](https?:\/\/[^"']+)["']/i, body) ->
        Enum.at(match, 1)
      # Plain image URL
      match = Regex.run(~r/(https?:\/\/\S+\.(?:jpg|jpeg|png|gif|webp))/i, body) ->
        Enum.at(match, 1)
      true ->
        nil
    end
  end

  def update_thread(thread, attrs) do
    thread
    |> Thread.mod_changeset(attrs)
    |> Repo.update()
  end

  def increment_view_count(thread) do
    from(t in Thread, where: t.id == ^thread.id)
    |> Repo.update_all(inc: [view_count: 1])
  end

  # --- Posts ---

  def list_posts(thread_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 25)
    offset = Keyword.get(opts, :offset, 0)
    include_hidden = Keyword.get(opts, :include_hidden, false)

    base = Post |> where([p], p.thread_id == ^thread_id)
    query = if include_hidden, do: base, else: where(base, [p], p.is_hidden == false)

    query
    |> order_by(:position)
    |> limit(^limit)
    |> offset(^offset)
    |> preload(user: :primary_group)
    |> Repo.all()
  end

  def get_post!(id) do
    Post |> Repo.get!(id) |> Repo.preload(user: :primary_group)
  end

  def create_post(attrs) do
    body = attrs["body"] || attrs[:body]
    user_id = attrs["user_id"] || attrs[:user_id]

    case ContentFilter.check(body || "", user_id) do
      {:ok, :clean} ->
        do_create_post(attrs)

      {:error, reason} ->
        {:error, :spam_detected, reason}
    end
  end

  defp do_create_post(attrs) do
    body = attrs["body"] || attrs[:body]
    existing_html = attrs["body_html"] || attrs[:body_html]
    attrs =
      if body && (is_nil(existing_html) or existing_html == "") do
        Map.put(attrs, "body_html", ForgeNexus.BBCode.to_html(body))
      else
        attrs
      end

    tx_result =
      Repo.transaction(fn ->
        thread_id = attrs["thread_id"] || attrs[:thread_id]

        position =
          from(p in Post, where: p.thread_id == ^thread_id, select: max(p.position))
          |> Repo.one()
          |> then(&((&1 || 0) + 1))

        post =
          %Post{}
          |> Post.changeset(Map.put(attrs, "position", position))
          |> Repo.insert!()

        now = DateTime.utc_now() |> DateTime.truncate(:second)
        user_id = attrs["user_id"] || attrs[:user_id]

        from(t in Thread, where: t.id == ^thread_id)
        |> Repo.update_all(inc: [reply_count: 1], set: [last_post_at: now, last_post_user_id: user_id])

        forum_id =
          from(t in Thread, where: t.id == ^thread_id, select: t.forum_id)
          |> Repo.one!()

        from(f in Forum, where: f.id == ^forum_id)
        |> Repo.update_all(inc: [post_count: 1], set: [last_post_at: now, last_post_user_id: user_id])

        from(u in ForgeNexus.Accounts.User, where: u.id == ^user_id)
        |> Repo.update_all(inc: [post_count: 1], set: [last_post_at: now])

        {post, forum_id, now, user_id}
      end)

    case tx_result do
      {:ok, {post, forum_id, now, user_id}} ->
        Task.start(fn -> Search.index_post(post) end)
        Task.start(fn -> process_mentions(post, user_id) end)
        Task.start(fn -> process_quotes(post, user_id) end)
        Task.start(fn -> notify_thread_watchers(post.thread_id, user_id, post) end)
        Task.start(fn ->
          ForgeNexusWeb.Endpoint.broadcast("forums:index", "forum_updated", %{
            forum_id: forum_id,
            delta: %{post_count: 1},
            last_post_at: now,
            last_post_user_id: user_id
          })
        end)
        {:ok, post}

      other ->
        other
    end
  end

  def update_post(post, attrs) do
    body = attrs["body"] || attrs[:body]
    body_before = post.body
    editor_id = attrs["editor_id"] || attrs[:editor_id] || post.user_id
    edit_reason = attrs["edit_reason"] || attrs[:edit_reason]

    attrs = if body do
      Map.put(attrs, "body_html", ForgeNexus.BBCode.to_html(body))
    else
      attrs
    end

    Repo.transaction(fn ->
      with {:ok, updated} <- post |> Post.edit_changeset(attrs) |> Repo.update() do
        # Audit row only when the body actually changed
        if body && body != body_before do
          %PostEdit{}
          |> Ecto.Changeset.change(%{
            post_id: updated.id,
            edited_by_id: editor_id,
            body_before: body_before,
            body_after: body,
            edit_reason: edit_reason
          })
          |> Repo.insert!()

          # Re-process @mentions and [quote=…] in the new body so newly
          # added references fire notifications. Existing references that
          # were already there will dedupe at notify time (one notif per user).
          Task.start(fn -> process_mentions(updated, editor_id) end)
          Task.start(fn -> process_quotes(updated, editor_id) end)
        end

        updated
      else
        {:error, changeset} -> Repo.rollback(changeset)
      end
    end)
  end

  @doc """
  Returns the chronological edit history for a post (oldest first).
  Each entry preloads the editor for display.
  """
  def list_post_edits(post_id) do
    PostEdit
    |> where([e], e.post_id == ^post_id)
    |> order_by(asc: :inserted_at)
    |> preload(:editor)
    |> Repo.all()
  end

  def mod_update_post(post, attrs) do
    post
    |> Post.mod_changeset(attrs)
    |> Repo.update()
  end

  # --- Thread Merging ---

  def merge_threads(source_thread_id, target_thread_id) do
    source = get_thread!(source_thread_id)
    target = get_thread!(target_thread_id)

    Repo.transaction(fn ->
      # Move all posts from source to target, marking their origin
      from(p in Post, where: p.thread_id == ^source.id)
      |> Repo.update_all(set: [
        thread_id: target.id,
        merged_from_thread_id: source.id
      ])

      # Update target thread reply count
      new_reply_count = Repo.one(
        from p in Post,
          where: p.thread_id == ^target.id and p.is_first_post == false,
          select: count(p.id)
      )

      target
      |> Ecto.Changeset.change(reply_count: new_reply_count)
      |> Repo.update!()

      # Mark source as merged and hidden
      source
      |> Thread.mod_changeset(%{merged_into_id: target.id, is_hidden: true})
      |> Repo.update!()

      target
    end)
  end

  # --- Polls ---

  def create_poll(attrs, options) do
    Repo.transaction(fn ->
      poll = %Poll{} |> Poll.changeset(attrs) |> Repo.insert!()

      Enum.each(Enum.with_index(options), fn {text, idx} ->
        %PollOption{}
        |> PollOption.changeset(%{text: text, position: idx, poll_id: poll.id})
        |> Repo.insert!()
      end)

      poll |> Repo.preload(:options)
    end)
  end

  # --- Stats helpers ---

  def count_threads do
    Repo.one(from t in Thread, where: t.is_hidden == false, select: count(t.id)) || 0
  end

  def count_posts do
    Repo.one(from p in Post, where: p.is_hidden == false, select: count(p.id)) || 0
  end

  def recent_threads(limit \\ 5) do
    Thread
    |> where([t], t.is_hidden == false)
    |> order_by(desc: :last_post_at)
    |> limit(^limit)
    |> preload([:user])
    |> Repo.all()
  end

  def trending_threads(period \\ "week", opts \\ []) do
    limit = Keyword.get(opts, :limit, 25)
    offset = Keyword.get(opts, :offset, 0)

    cutoff = case period do
      "today" -> DateTime.utc_now() |> DateTime.add(-1 * 24 * 3600, :second)
      "week" -> DateTime.utc_now() |> DateTime.add(-7 * 24 * 3600, :second)
      "month" -> DateTime.utc_now() |> DateTime.add(-30 * 24 * 3600, :second)
      _ -> nil
    end

    query = Thread
      |> where([t], t.is_hidden == false)
      |> join(:inner, [t], f in Forum, on: t.forum_id == f.id)
      |> preload([:user, :forum])

    query = if cutoff do
      where(query, [t], t.last_post_at >= ^cutoff)
    else
      query
    end

    query
    |> order_by([t], [desc: fragment("(? * 2 + ?)", t.reply_count, t.view_count)])
    |> limit(^limit)
    |> offset(^offset)
    |> Repo.all()
  end

  # === Post Ratings ===

  def rate_post(post_id, user_id, rating_type) do
    post = Repo.get(Post, post_id)

    cond do
      is_nil(post) ->
        {:error, :not_found}

      # Block self-rating. Forums universally prevent users from
      # rating their own posts; without this guard a user could pad
      # their own like counts (and previously this WAS happening —
      # only reputation accrual was self-blocked, not the row insert).
      post.user_id == user_id ->
        {:error, :self_rating}

      true ->
        case Repo.get_by(PostRating, post_id: post_id, user_id: user_id, rating_type: rating_type) do
          nil ->
            result =
              %PostRating{}
              |> PostRating.changeset(%{post_id: post_id, user_id: user_id, rating_type: rating_type})
              |> Repo.insert()

            if rating_type == "like" do
              log_reputation_event(post.user_id, "post_liked", 1, "post", post_id)
              Task.start(fn -> notify_post_liked(post, user_id) end)
            end

            result

          existing ->
            Repo.delete(existing)  # Toggle off
        end
    end
  end

  defp notify_post_liked(post, actor_id) do
    actor = Accounts.get_user!(actor_id)
    thread = Repo.get(Thread, post.thread_id)
    relative_url = if thread, do: "/threads/#{thread.slug}#post-#{post.id}", else: nil

    prefs = Accounts.get_preferences(post.user_id)

    if prefs.notify_reactions do
      Notifications.create_notification(%{
        type: "like",
        title: "#{actor.username} liked your post",
        body: String.slice(post.body || "", 0, 200),
        url: relative_url,
        user_id: post.user_id,
        actor_id: actor_id,
        metadata: %{
          thread_id: post.thread_id,
          post_id: post.id,
          thread_slug: thread && thread.slug
        }
      })
    end
  rescue
    e ->
      require Logger
      Logger.error("notify_post_liked failed: #{inspect(e)}")
      :ok
  end

  def get_post_ratings(post_id) do
    PostRating
    |> where([r], r.post_id == ^post_id)
    |> Repo.all()
    |> Enum.group_by(fn r -> r.rating_type end)
    |> Enum.map(fn {type, ratings} ->
      %{type: type, count: length(ratings)}
    end)
  end

  def get_user_ratings_for_post(post_id, user_id) do
    PostRating
    |> where([r], r.post_id == ^post_id and r.user_id == ^user_id)
    |> select([r], r.rating_type)
    |> Repo.all()
  end

  def user_rating_summary(user_id) do
    from(r in PostRating,
      join: p in Post, on: p.id == r.post_id,
      where: p.user_id == ^user_id,
      group_by: r.rating_type,
      select: {r.rating_type, count(r.id)}
    ) |> Repo.all() |> Map.new()
  end

  # === Post Reactions (Emoji) ===

  def toggle_reaction(post_id, user_id, reaction_type) do
    post = Repo.get(Post, post_id)

    cond do
      is_nil(post) ->
        {:error, :not_found}

      # Same self-reaction guard as rate_post — don't let users react to their own posts.
      post.user_id == user_id ->
        {:error, :self_reaction}

      true ->
        case Repo.get_by(Reaction, reactable_type: "post", reactable_id: post_id, user_id: user_id, type: reaction_type) do
          nil ->
            result =
              %Reaction{}
              |> Reaction.changeset(%{type: reaction_type, reactable_type: "post", reactable_id: post_id, user_id: user_id})
              |> Repo.insert()

            # Fire reaction notification (function existed but was never called).
            with {:ok, _reaction} <- result do
              Task.start(fn -> notify_post_reaction(post, user_id, reaction_type) end)
            end

            result

          existing ->
            Repo.delete(existing)
        end
    end
  end

  defp notify_post_reaction(post, actor_id, reaction_type) do
    prefs = Accounts.get_preferences(post.user_id)

    if prefs.notify_reactions do
      thread = Repo.get(Thread, post.thread_id)
      relative_url = if thread, do: "/threads/#{thread.slug}#post-#{post.id}", else: nil
      actor = Accounts.get_user!(actor_id)

      Notifications.create_notification(%{
        type: "reaction",
        title: "#{actor.username} reacted #{reaction_type} to your post",
        body: String.slice(post.body || "", 0, 200),
        url: relative_url,
        user_id: post.user_id,
        actor_id: actor_id,
        metadata: %{
          thread_id: post.thread_id,
          post_id: post.id,
          thread_slug: thread && thread.slug,
          reaction_type: reaction_type
        }
      })
    end
  rescue
    e ->
      require Logger
      Logger.error("notify_post_reaction failed: #{inspect(e)}")
      :ok
  end

  def list_reactions(post_id) do
    Reaction
    |> where([r], r.reactable_type == "post" and r.reactable_id == ^post_id)
    |> Repo.all()
  end

  def reaction_counts(post_id) do
    Reaction
    |> where([r], r.reactable_type == "post" and r.reactable_id == ^post_id)
    |> group_by([r], r.type)
    |> select([r], {r.type, count(r.id)})
    |> Repo.all()
    |> Map.new()
  end

  def user_reactions_for_post(post_id, user_id) do
    Reaction
    |> where([r], r.reactable_type == "post" and r.reactable_id == ^post_id and r.user_id == ^user_id)
    |> select([r], r.type)
    |> Repo.all()
  end

  def reaction_counts_for_posts(post_ids) when is_list(post_ids) do
    Reaction
    |> where([r], r.reactable_type == "post" and r.reactable_id in ^post_ids)
    |> group_by([r], [r.reactable_id, r.type])
    |> select([r], {r.reactable_id, r.type, count(r.id)})
    |> Repo.all()
    |> Enum.group_by(fn {post_id, _type, _count} -> post_id end, fn {_post_id, type, count} -> %{type: type, count: count} end)
  end

  def user_reactions_for_posts(post_ids, user_id) when is_list(post_ids) do
    Reaction
    |> where([r], r.reactable_type == "post" and r.reactable_id in ^post_ids and r.user_id == ^user_id)
    |> select([r], {r.reactable_id, r.type})
    |> Repo.all()
    |> Enum.group_by(fn {post_id, _type} -> post_id end, fn {_post_id, type} -> type end)
  end

  def post_has_popular_reaction?(post_id, threshold \\ 10) do
    Reaction
    |> where([r], r.reactable_type == "post" and r.reactable_id == ^post_id)
    |> group_by([r], r.type)
    |> having([r], count(r.id) >= ^threshold)
    |> limit(1)
    |> Repo.one()
    |> is_nil()
    |> Kernel.not()
  end

  # === Badges ===

  def list_badges do
    Badge |> where([b], b.is_active == true) |> order_by(asc: :position) |> Repo.all()
  end

  def list_all_badges, do: Badge |> order_by(asc: :position) |> Repo.all()
  def get_badge!(id), do: Repo.get!(Badge, id)

  def create_badge(attrs), do: %Badge{} |> Badge.changeset(attrs) |> Repo.insert()
  def update_badge(id, attrs), do: get_badge!(id) |> Badge.changeset(attrs) |> Repo.update()
  def delete_badge(id), do: get_badge!(id) |> Repo.delete()

  def award_badge(user_id, badge_id, awarded_by_id \\ nil, reason \\ nil) do
    %UserBadge{}
    |> UserBadge.changeset(%{user_id: user_id, badge_id: badge_id, awarded_by_id: awarded_by_id, reason: reason})
    |> Repo.insert(on_conflict: :nothing)
  end

  def revoke_badge(user_id, badge_id) do
    case Repo.get_by(UserBadge, user_id: user_id, badge_id: badge_id) do
      nil -> {:error, :not_found}
      ub -> Repo.delete(ub)
    end
  end

  def user_badges(user_id) do
    UserBadge
    |> where([ub], ub.user_id == ^user_id)
    |> preload(:badge)
    |> order_by(desc: :inserted_at)
    |> Repo.all()
  end

  def feature_badge(user_id, badge_id, featured) do
    case Repo.get_by(UserBadge, user_id: user_id, badge_id: badge_id) do
      nil -> {:error, :not_found}
      ub -> ub |> Ecto.Changeset.change(is_featured: featured) |> Repo.update()
    end
  end

  def check_auto_badges(user) do
    badges = Badge |> where([b], b.is_auto == true and b.is_active == true) |> Repo.all()

    for badge <- badges do
      criteria = badge.auto_criteria || %{}
      earned = case criteria do
        %{"type" => "post_count", "value" => v} -> user.post_count >= v
        %{"type" => "thread_count", "value" => v} -> user.thread_count >= v
        %{"type" => "reputation", "value" => v} -> user.reputation >= v
        %{"type" => "days_member", "value" => v} ->
          days = DateTime.diff(DateTime.utc_now(), user.inserted_at, :second) / 86400
          days >= v
        _ -> false
      end

      if earned do
        case award_badge(user.id, badge.id) do
          {:ok, _} ->
            log_reputation_event(user.id, "achievement_earned", 5, "badge", badge.id)
          _ -> :ok
        end
      end
    end
  end

  # === Best Answer / Solved ===

  def mark_solved(thread_id, post_id) do
    thread = Repo.get!(Thread, thread_id)
    result = thread |> Ecto.Changeset.change(solved_post_id: post_id, is_solved: true) |> Repo.update()

    case result do
      {:ok, _} ->
        post = Repo.get(Post, post_id)
        if post, do: log_reputation_event(post.user_id, "best_answer", 5, "post", post_id)
      _ -> :ok
    end

    result
  end

  def unmark_solved(thread_id) do
    thread = Repo.get!(Thread, thread_id)
    thread |> Ecto.Changeset.change(solved_post_id: nil, is_solved: false) |> Repo.update()
  end

  # === Thread Prefixes ===

  def list_prefixes_for_forum(forum_id) do
    ThreadPrefix
    |> where([p], p.forum_id == ^forum_id or p.is_global == true)
    |> order_by(asc: :position)
    |> Repo.all()
  end

  def list_all_prefixes do
    ThreadPrefix |> order_by(asc: :position) |> preload(:forum) |> Repo.all()
  end

  def create_prefix(attrs), do: %ThreadPrefix{} |> ThreadPrefix.changeset(attrs) |> Repo.insert()
  def update_prefix(id, attrs), do: Repo.get!(ThreadPrefix, id) |> ThreadPrefix.changeset(attrs) |> Repo.update()
  def delete_prefix(id), do: Repo.get!(ThreadPrefix, id) |> Repo.delete()

  def set_thread_prefix(thread_id, prefix_id) do
    Repo.get!(Thread, thread_id)
    |> Ecto.Changeset.change(prefix_id: prefix_id)
    |> Repo.update()
  end

  # === Drafts ===

  def save_draft(user_id, context_type, context_id, body, title \\ nil) do
    case Repo.get_by(PostDraft, user_id: user_id, context_type: context_type, context_id: context_id || "") do
      nil ->
        %PostDraft{}
        |> PostDraft.changeset(%{user_id: user_id, context_type: context_type, context_id: context_id || "", body: body, title: title})
        |> Repo.insert()

      existing ->
        existing
        |> PostDraft.changeset(%{body: body, title: title})
        |> Repo.update()
    end
  end

  def get_draft(user_id, context_type, context_id) do
    Repo.get_by(PostDraft, user_id: user_id, context_type: context_type, context_id: context_id || "")
  end

  def delete_draft(user_id, context_type, context_id) do
    case Repo.get_by(PostDraft, user_id: user_id, context_type: context_type, context_id: context_id || "") do
      nil -> :ok
      draft -> Repo.delete(draft)
    end
  end

  # === Similar Threads ===

  def find_similar_threads(title, forum_id \\ nil, limit \\ 5) do
    base = Thread
      |> where([t], t.is_hidden == false)
      |> where([t], fragment("similarity(?, ?) > 0.2", t.title, ^title))
      |> order_by([t], fragment("similarity(?, ?) DESC", t.title, ^title))
      |> limit(^limit)
      |> preload([:forum, :user])

    base = if forum_id, do: where(base, [t], t.forum_id == ^forum_id), else: base

    Repo.all(base)
  rescue
    # If pg_trgm is not installed, fall back to ILIKE
    _ ->
      words = title |> String.split() |> Enum.take(3) |> Enum.join("%")
      Thread
      |> where([t], t.is_hidden == false and ilike(t.title, ^"%#{words}%"))
      |> order_by(desc: :inserted_at)
      |> limit(^limit)
      |> preload([:forum, :user])
      |> Repo.all()
  end

  # === Thread Read Status (Unread Tracking) ===

  def list_threads_with_read_status(forum_id, user_id, opts \\ []) do
    threads = list_threads(forum_id, opts)

    if user_id do
      thread_ids = Enum.map(threads, & &1.id)

      reads =
        from(tr in ThreadRead,
          where: tr.user_id == ^user_id and tr.thread_id in ^thread_ids,
          select: {tr.thread_id, tr.last_read_at}
        )
        |> Repo.all()
        |> Map.new()

      # Count new posts per thread since last read
      new_post_counts =
        from(p in Post,
          join: tr in ThreadRead,
            on: tr.thread_id == p.thread_id and tr.user_id == ^user_id,
          where: p.thread_id in ^thread_ids and p.is_hidden == false and p.inserted_at > tr.last_read_at,
          group_by: p.thread_id,
          select: {p.thread_id, count(p.id)}
        )
        |> Repo.all()
        |> Map.new()

      Enum.map(threads, fn thread ->
        last_read = Map.get(reads, thread.id)
        has_unread = is_nil(last_read) or
          (!is_nil(thread.last_post_at) and !is_nil(last_read) and DateTime.compare(thread.last_post_at, last_read) == :gt)
        new_post_count = if is_nil(last_read), do: thread.reply_count + 1, else: Map.get(new_post_counts, thread.id, 0)
        thread
        |> Map.put(:has_unread, has_unread)
        |> Map.put(:last_read_at, last_read)
        |> Map.put(:new_post_count, if(has_unread, do: max(new_post_count, 0), else: 0))
      end)
    else
      Enum.map(threads, fn thread ->
        thread |> Map.put(:has_unread, false) |> Map.put(:last_read_at, nil) |> Map.put(:new_post_count, 0)
      end)
    end
  end

  def mark_thread_read(thread_id, user_id) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    case Repo.get_by(ThreadRead, thread_id: thread_id, user_id: user_id) do
      nil ->
        %ThreadRead{}
        |> ThreadRead.changeset(%{thread_id: thread_id, user_id: user_id, last_read_at: now})
        |> Repo.insert()

      existing ->
        existing
        |> Ecto.Changeset.change(last_read_at: now)
        |> Repo.update()
    end
  end

  def mark_forum_read(forum_id, user_id) do
    thread_ids =
      from(t in Thread, where: t.forum_id == ^forum_id and t.is_hidden == false, select: t.id)
      |> Repo.all()

    for thread_id <- thread_ids do
      mark_thread_read(thread_id, user_id)
    end

    :ok
  end

  def unread_counts_by_forum(user_id) do
    from(t in Thread,
      left_join: tr in ThreadRead,
        on: tr.thread_id == t.id and tr.user_id == ^user_id,
      where: t.is_hidden == false,
      where: is_nil(tr.id) or tr.last_read_at < t.last_post_at,
      group_by: t.forum_id,
      select: {t.forum_id, count(t.id)}
    )
    |> Repo.all()
    |> Map.new()
  end

  # === Content Ignores (Mute Forums/Threads) ===

  def ignore_forum(user_id, forum_id) do
    %ContentIgnore{}
    |> ContentIgnore.changeset(%{user_id: user_id, forum_id: forum_id})
    |> Repo.insert(on_conflict: :nothing)
  end

  def ignore_thread(user_id, thread_id) do
    %ContentIgnore{}
    |> ContentIgnore.changeset(%{user_id: user_id, thread_id: thread_id})
    |> Repo.insert(on_conflict: :nothing)
  end

  def unignore_forum(user_id, forum_id) do
    case Repo.get_by(ContentIgnore, user_id: user_id, forum_id: forum_id) do
      nil -> {:error, :not_found}
      ignore -> Repo.delete(ignore)
    end
  end

  def unignore_thread(user_id, thread_id) do
    case Repo.get_by(ContentIgnore, user_id: user_id, thread_id: thread_id) do
      nil -> {:error, :not_found}
      ignore -> Repo.delete(ignore)
    end
  end

  def ignored_forum_ids(user_id) do
    from(ci in ContentIgnore,
      where: ci.user_id == ^user_id and not is_nil(ci.forum_id),
      select: ci.forum_id
    ) |> Repo.all()
  end

  def ignored_thread_ids(user_id) do
    from(ci in ContentIgnore,
      where: ci.user_id == ^user_id and not is_nil(ci.thread_id),
      select: ci.thread_id
    ) |> Repo.all()
  end

  def list_ignores(user_id) do
    from(ci in ContentIgnore,
      where: ci.user_id == ^user_id,
      preload: [:forum, :thread],
      order_by: [desc: :inserted_at]
    ) |> Repo.all()
  end

  # === Thread Ratings ===

  def rate_thread(thread_id, user_id, rating) do
    case Repo.get_by(ThreadRating, thread_id: thread_id, user_id: user_id) do
      nil ->
        %ThreadRating{}
        |> ThreadRating.changeset(%{thread_id: thread_id, user_id: user_id, rating: rating})
        |> Repo.insert()

      existing ->
        existing
        |> ThreadRating.changeset(%{rating: rating})
        |> Repo.update()
    end
  end

  def get_thread_rating_stats(thread_id) do
    from(r in ThreadRating,
      where: r.thread_id == ^thread_id,
      select: %{average: avg(r.rating), count: count(r.id)}
    )
    |> Repo.one()
    |> then(fn
      nil -> %{average: 0, count: 0}
      stats -> %{average: Float.round((stats.average || 0) / 1, 1), count: stats.count}
    end)
  end

  def get_user_thread_rating(thread_id, user_id) do
    Repo.get_by(ThreadRating, thread_id: thread_id, user_id: user_id)
  end

  # === Thread Subscriptions ===

  def subscribe_thread(thread_id, user_id, level \\ "watching") do
    case Repo.get_by(ThreadSubscription, thread_id: thread_id, user_id: user_id) do
      nil ->
        %ThreadSubscription{}
        |> ThreadSubscription.changeset(%{thread_id: thread_id, user_id: user_id, notification_level: level})
        |> Repo.insert()

      existing ->
        existing
        |> ThreadSubscription.changeset(%{notification_level: level})
        |> Repo.update()
    end
  end

  def unsubscribe_thread(thread_id, user_id) do
    case Repo.get_by(ThreadSubscription, thread_id: thread_id, user_id: user_id) do
      nil -> :ok
      sub -> Repo.delete(sub)
    end
  end

  def get_thread_subscription(thread_id, user_id) do
    Repo.get_by(ThreadSubscription, thread_id: thread_id, user_id: user_id)
  end

  # === User Activity ===

  def user_activity(user_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 25)
    offset = Keyword.get(opts, :offset, 0)

    posts = from(p in Post,
      where: p.user_id == ^user_id and p.is_hidden == false,
      order_by: [desc: :inserted_at],
      limit: ^limit,
      offset: ^offset,
      preload: [thread: :forum]
    ) |> Repo.all()

    threads = from(t in Thread,
      where: t.user_id == ^user_id and t.is_hidden == false,
      order_by: [desc: :inserted_at],
      limit: ^limit,
      offset: ^offset,
      preload: [:forum]
    ) |> Repo.all()

    %{posts: posts, threads: threads}
  end

  # === Private Forums ===

  def list_categories_for_user(user_id) do
    categories = list_categories()

    if user_id do
      ignored = ignored_forum_ids(user_id)
      Enum.map(categories, fn cat ->
        filtered_forums = Enum.reject(cat.forums, fn f ->
          f.is_private || Enum.member?(ignored, f.id)
        end)
        %{cat | forums: filtered_forums}
      end)
    else
      Enum.map(categories, fn cat ->
        filtered_forums = Enum.reject(cat.forums, fn f -> f.is_private end)
        %{cat | forums: filtered_forums}
      end)
    end
  end

  # === Post Bookmarks ===

  def toggle_post_bookmark(user_id, post_id, note \\ nil) do
    case Repo.get_by(PostBookmark, user_id: user_id, post_id: post_id) do
      nil ->
        %PostBookmark{}
        |> PostBookmark.changeset(%{user_id: user_id, post_id: post_id, note: note})
        |> Repo.insert()

      existing ->
        Repo.delete(existing)
    end
  end

  def list_post_bookmarks(user_id) do
    from(b in PostBookmark,
      where: b.user_id == ^user_id,
      order_by: [desc: :inserted_at],
      preload: [post: [:user, thread: :forum]]
    )
    |> Repo.all()
  end

  def is_post_bookmarked?(user_id, post_id) do
    Repo.exists?(from b in PostBookmark, where: b.user_id == ^user_id and b.post_id == ^post_id)
  end

  def post_bookmark_ids(user_id) do
    from(b in PostBookmark, where: b.user_id == ^user_id, select: b.post_id)
    |> Repo.all()
    |> MapSet.new()
  end

  # === Thread Watcher Notifications ===

  defp notify_thread_watchers(thread_id, post_author_id, post) do
    thread = Repo.get(Thread, thread_id) |> Repo.preload(:user)
    if thread do
      # Find all users watching this thread, excluding the post author
      watchers =
        from(s in ThreadSubscription,
          where: s.thread_id == ^thread_id and s.user_id != ^post_author_id and s.notification_level == "watching",
          select: s.user_id
        )
        |> Repo.all()

      post_author = Repo.get(ForgeNexus.Accounts.User, post_author_id)
      actor_name = if post_author, do: post_author.username, else: "Someone"

      for watcher_id <- watchers do
        attrs = %{
          type: "reply",
          title: actor_name <> " replied to \"" <> thread.title <> "\"",
          body: String.slice(post.body || "", 0, 200),
          link: "/threads/" <> thread.slug,
          target_type: "thread",
          target_id: thread.id,
          user_id: watcher_id,
          actor_id: post_author_id,
          metadata: %{thread_id: thread.id, thread_slug: thread.slug, post_id: post.id}
        }

        case Notifications.create_notification(attrs) do
          {:ok, notification} ->
            Notifications.broadcast_notification(notification, post_author)
          _ -> :ok
        end

        # Enqueue email notification
        NotificationEmailer.enqueue_reply_notification(
          watcher_id, actor_name, thread.title, thread.slug
        )
      end
    end
  end

  # === Bulk Thread Actions ===

  def bulk_update_threads(thread_ids, attrs) when is_list(thread_ids) do
    from(t in Thread, where: t.id in ^thread_ids)
    |> Repo.update_all(set: Enum.to_list(attrs))

    :ok
  end

  def bulk_move_threads(thread_ids, target_forum_id) when is_list(thread_ids) do
    from(t in Thread, where: t.id in ^thread_ids)
    |> Repo.update_all(set: [forum_id: target_forum_id])

    :ok
  end

  def bulk_hide_threads(thread_ids) when is_list(thread_ids) do
    from(t in Thread, where: t.id in ^thread_ids)
    |> Repo.update_all(set: [is_hidden: true])
    :ok
  end

  # === Mention Detection & Notification ===

  @doc """
  Extracts @username mentions from post body text.
  Returns a list of unique usernames (strings).
  """
  def detect_mentions(body) when is_binary(body) do
    ~r/@(\w+)/
    |> Regex.scan(body)
    |> Enum.map(fn [_, username] -> username end)
    |> Enum.uniq()
  end

  def detect_mentions(_), do: []

  defp process_mentions(post, author_id) do
    body = post.body || ""
    usernames = detect_mentions(body)

    if usernames != [] do
      # Look up the author for their username
      author = Accounts.get_user!(author_id)

      # Look up the thread for building the post URL
      thread = Repo.get(Thread, post.thread_id)

      mentioned_users =
        usernames
        |> Enum.map(&Accounts.get_user_by_username/1)
        |> Enum.reject(&is_nil/1)
        |> Enum.reject(fn user -> user.id == author_id end)

      # In-app notification keeps the relative URL (frontend resolves it).
      # Email needs an absolute URL so the link works in any mail client.
      relative_url = if thread, do: "/threads/#{thread.slug}#post-#{post.id}", else: nil
      base = Application.get_env(:forge_nexus, :frontend_url, "http://localhost:5173")
      absolute_url = if relative_url, do: base <> relative_url, else: nil

      for user <- mentioned_users do
        prefs = Accounts.get_preferences(user.id)

        if prefs.notify_mentions do
          Notifications.create_notification(%{
            type: "mention",
            title: "#{author.username} mentioned you",
            body: String.slice(body, 0, 200),
            url: relative_url,
            user_id: user.id,
            actor_id: author_id,
            metadata: %{
              thread_id: post.thread_id,
              post_id: post.id,
              thread_slug: thread && thread.slug
            }
          })
        end

        if prefs.email_mentions do
          NotificationEmailer.enqueue_mention_notification(
            user.id,
            author.username,
            absolute_url
          )
        end
      end
    end
  rescue
    e ->
      require Logger
      Logger.error("process_mentions failed: #{inspect(e)}")
      :ok
  end

  @doc """
  Extracts usernames quoted via `[quote=name]` or `[quote="name"]` BBCode.
  Returns a list of unique usernames (strings).
  """
  def detect_quotes(body) when is_binary(body) do
    ~r/\[quote="?([^\]"]+)"?\]/i
    |> Regex.scan(body)
    |> Enum.map(fn [_, username] -> String.trim(username) end)
    |> Enum.reject(&(&1 == ""))
    |> Enum.uniq()
  end

  def detect_quotes(_), do: []

  defp process_quotes(post, author_id) do
    body = post.body || ""
    usernames = detect_quotes(body)

    if usernames != [] do
      author = Accounts.get_user!(author_id)
      thread = Repo.get(Thread, post.thread_id)

      quoted_users =
        usernames
        |> Enum.map(&Accounts.get_user_by_username/1)
        |> Enum.reject(&is_nil/1)
        |> Enum.reject(fn user -> user.id == author_id end)

      relative_url = if thread, do: "/threads/#{thread.slug}#post-#{post.id}", else: nil
      base = Application.get_env(:forge_nexus, :frontend_url, "http://localhost:5173")
      absolute_url = if relative_url, do: base <> relative_url, else: nil

      for user <- quoted_users do
        prefs = Accounts.get_preferences(user.id)

        # Reuse the mentions preference — being quoted is conceptually the
        # same opt-in surface as @mention. If user separation matters later,
        # add a dedicated `notify_quotes` preference.
        if prefs.notify_mentions do
          Notifications.create_notification(%{
            type: "quote",
            title: "#{author.username} quoted you",
            body: String.slice(body, 0, 200),
            url: relative_url,
            user_id: user.id,
            actor_id: author_id,
            metadata: %{
              thread_id: post.thread_id,
              post_id: post.id,
              thread_slug: thread && thread.slug
            }
          })
        end

        if prefs.email_mentions do
          NotificationEmailer.enqueue_mention_notification(
            user.id,
            author.username,
            absolute_url
          )
        end
      end
    end
  rescue
    e ->
      require Logger
      Logger.error("process_quotes failed: #{inspect(e)}")
      :ok
  end

  # --- Stats (added for stats page) ---

  def new_threads_this_month do
    start_of_month = Date.utc_today() |> Date.beginning_of_month() |> DateTime.new!(~T[00:00:00], "Etc/UTC")
    Repo.one(from t in Thread, where: t.is_hidden == false and t.inserted_at >= ^start_of_month, select: count(t.id)) || 0
  end

  def new_posts_this_month do
    start_of_month = Date.utc_today() |> Date.beginning_of_month() |> DateTime.new!(~T[00:00:00], "Etc/UTC")
    Repo.one(from p in Post, where: p.is_hidden == false and p.inserted_at >= ^start_of_month, select: count(p.id)) || 0
  end

  def most_popular_threads(limit \\ 10) do
    Thread
    |> where([t], t.is_hidden == false)
    |> order_by(desc: :view_count)
    |> limit(^limit)
    |> preload([:user, :forum])
    |> Repo.all()
  end

  def monthly_thread_growth(months \\ 12) do
    cutoff = DateTime.utc_now() |> DateTime.add(-months * 30 * 24 * 3600, :second)

    from(t in Thread,
      where: t.is_hidden == false and t.inserted_at >= ^cutoff,
      group_by: fragment("to_char(?, 'YYYY-MM')", t.inserted_at),
      select: %{
        month: fragment("to_char(?, 'YYYY-MM')", t.inserted_at),
        count: count(t.id)
      },
      order_by: fragment("to_char(?, 'YYYY-MM')", t.inserted_at)
    )
    |> Repo.all()
  end

  def monthly_post_growth(months \\ 12) do
    cutoff = DateTime.utc_now() |> DateTime.add(-months * 30 * 24 * 3600, :second)

    from(p in Post,
      where: p.is_hidden == false and p.inserted_at >= ^cutoff,
      group_by: fragment("to_char(?, 'YYYY-MM')", p.inserted_at),
      select: %{
        month: fragment("to_char(?, 'YYYY-MM')", p.inserted_at),
        count: count(p.id)
      },
      order_by: fragment("to_char(?, 'YYYY-MM')", p.inserted_at)
    )
    |> Repo.all()
  end


  alias ForgeNexus.Forums.ReputationEvent

  def log_reputation_event(user_id, event_type, points, source_type \\ nil, source_id \\ nil) do
    %ReputationEvent{}
    |> ReputationEvent.changeset(%{
      user_id: user_id,
      event_type: event_type,
      points: points,
      source_type: source_type,
      source_id: source_id
    })
    |> Repo.insert()
  end

  def get_reputation_breakdown(user_id) do
    from(re in ReputationEvent,
      where: re.user_id == ^user_id,
      group_by: re.event_type,
      select: %{event_type: re.event_type, total_points: sum(re.points), count: count(re.id)}
    )
    |> Repo.all()
  end

  def get_reputation_history(user_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 25)
    offset = Keyword.get(opts, :offset, 0)

    from(re in ReputationEvent,
      where: re.user_id == ^user_id,
      order_by: [desc: re.inserted_at],
      limit: ^limit,
      offset: ^offset
    )
    |> Repo.all()
  end

  # --- Aliases / convenience ---

  def list_forums do
    Forum |> order_by(:position) |> Repo.all()
  end

  def get_thread_by_id!(id), do: get_thread!(id)

  def list_prefixes(forum_id), do: list_prefixes_for_forum(forum_id)

  def list_all_posts(thread_id) do
    Post
    |> where([p], p.thread_id == ^thread_id and p.is_hidden == false)
    |> order_by(asc: :inserted_at)
    |> preload([:user])
    |> Repo.all()
  end

  def get_first_post(thread_id) do
    Post
    |> where([p], p.thread_id == ^thread_id)
    |> order_by(asc: :inserted_at)
    |> limit(1)
    |> preload([:user])
    |> Repo.one()
  end

  def list_scheduled_threads(user_id) do
    Thread
    |> where([t], t.user_id == ^user_id and t.status == "scheduled")
    |> order_by(asc: :scheduled_at)
    |> Repo.all()
  end

  def user_activity_heatmap(user_id) do
    start_date = Date.utc_today() |> Date.add(-365)
    start_dt = DateTime.new!(start_date, ~T[00:00:00], "Etc/UTC")

    from(p in Post,
      where: p.user_id == ^user_id and p.inserted_at >= ^start_dt,
      group_by: fragment("date_trunc('day', ?)::date", p.inserted_at),
      select: %{
        date: fragment("date_trunc('day', ?)::date", p.inserted_at),
        count: count(p.id)
      }
    )
    |> Repo.all()
  end

  # --- Custom BBCodes ---

  def list_custom_bbcodes do
    CustomBBCode |> order_by(:tag_name) |> Repo.all()
  end

  def list_active_custom_bbcodes do
    CustomBBCode |> where([b], b.is_active == true) |> Repo.all()
  end

  def create_custom_bbcode(attrs) do
    %CustomBBCode{} |> CustomBBCode.changeset(attrs) |> Repo.insert()
  end

  def update_custom_bbcode(id, attrs) do
    case Repo.get(CustomBBCode, id) do
      nil -> {:error, :not_found}
      bbcode -> bbcode |> CustomBBCode.changeset(attrs) |> Repo.update()
    end
  end

  def delete_custom_bbcode(id) do
    case Repo.get(CustomBBCode, id) do
      nil -> {:error, :not_found}
      bbcode -> Repo.delete(bbcode)
    end
  end

  # --- Forum Webhooks ---

  def list_forum_webhooks do
    ForumWebhook |> order_by(desc: :inserted_at) |> Repo.all()
  end

  def get_forum_webhook!(id), do: Repo.get!(ForumWebhook, id)

  def get_forum_webhook(id), do: Repo.get(ForumWebhook, id)

  def create_forum_webhook(attrs) do
    %ForumWebhook{} |> ForumWebhook.changeset(attrs) |> Repo.insert()
  end

  def update_forum_webhook(id, attrs) do
    case Repo.get(ForumWebhook, id) do
      nil -> {:error, :not_found}
      webhook -> webhook |> ForumWebhook.changeset(attrs) |> Repo.update()
    end
  end

  def delete_forum_webhook(id) do
    case Repo.get(ForumWebhook, id) do
      nil -> {:error, :not_found}
      webhook -> Repo.delete(webhook)
    end
  end

  @doc "List recent delivery attempts for a webhook, newest first."
  def list_webhook_deliveries(webhook_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)

    ForgeNexus.Forums.WebhookDelivery
    |> where([d], d.webhook_id == ^webhook_id)
    |> order_by(desc: :delivered_at)
    |> limit(^limit)
    |> Repo.all()
  end

  @doc "Record a webhook delivery attempt (success or failure)."
  def record_webhook_delivery(attrs) do
    %ForgeNexus.Forums.WebhookDelivery{}
    |> ForgeNexus.Forums.WebhookDelivery.changeset(attrs)
    |> Repo.insert()
  end

  def fire_webhook_event(event, payload) when is_binary(event) and is_map(payload) do
    webhooks =
      ForumWebhook
      |> where([w], w.is_active == true)
      |> Repo.all()
      |> Enum.filter(fn w ->
        events = w.events || []
        # Empty events list means "subscribe to all events"
        events == [] or event in events
      end)

    Enum.each(webhooks, fn webhook ->
      %{webhook_id: webhook.id, event: event, payload: payload}
      |> ForgeNexus.Workers.ForumWebhookWorker.new()
      |> Oban.insert()
    end)

    :ok
  end

  # --- Forum Permissions ---

  def list_forum_permissions(forum_id) do
    ForumPermission
    |> where([p], p.forum_id == ^forum_id)
    |> preload(:group)
    |> Repo.all()
  end

  def set_forum_permissions(forum_id, group_id, perms) when is_map(perms) do
    attrs = Map.merge(%{forum_id: forum_id, group_id: group_id}, perms)

    case Repo.get_by(ForumPermission, forum_id: forum_id, group_id: group_id) do
      nil ->
        %ForumPermission{} |> ForumPermission.changeset(attrs) |> Repo.insert()

      existing ->
        existing |> ForumPermission.changeset(attrs) |> Repo.update()
    end
  end

  # --- Thread Participants / Private Threads ---

  def list_thread_participants(thread_id) do
    ThreadParticipant
    |> where([tp], tp.thread_id == ^thread_id)
    |> preload(:user)
    |> Repo.all()
    |> Enum.map(fn tp ->
      %{
        id: tp.user_id,
        added_at: tp.added_at,
        username: tp.user && tp.user.username,
        slug: tp.user && tp.user.slug,
        avatar_url: tp.user && tp.user.avatar_url
      }
    end)
  end

  def add_thread_participant(thread_id, user_id) do
    %ThreadParticipant{}
    |> ThreadParticipant.changeset(%{
      thread_id: thread_id,
      user_id: user_id,
      added_at: DateTime.utc_now() |> DateTime.truncate(:second)
    })
    |> Repo.insert()
  end

  def remove_thread_participant(thread_id, user_id) do
    case Repo.get_by(ThreadParticipant, thread_id: thread_id, user_id: user_id) do
      nil -> {:error, :not_found}
      participant -> Repo.delete(participant)
    end
  end

  def can_view_thread?(%Thread{} = thread, user) do
    cond do
      not Map.get(thread, :is_private, false) ->
        true

      is_nil(user) ->
        false

      thread.user_id == user.id ->
        true

      Repo.exists?(
        from tp in ThreadParticipant,
          where: tp.thread_id == ^thread.id and tp.user_id == ^user.id
      ) ->
        true

      true ->
        false
    end
  end

  def can_view_thread?(_, _), do: false

  # =====================
  # Plugin-friendly helpers (used by no-code nodes)
  # =====================

  def pin_target("thread", id), do: pin_thread(id)
  def pin_target(_, _), do: {:error, :unsupported_target}

  def unpin_target("thread", id), do: unpin_thread(id)
  def unpin_target(_, _), do: {:error, :unsupported_target}

  def pin_thread(thread_id) do
    case Repo.get(Thread, thread_id) do
      nil -> {:error, :not_found}
      thread -> thread |> Ecto.Changeset.change(is_pinned: true) |> Repo.update()
    end
  end

  def unpin_thread(thread_id) do
    case Repo.get(Thread, thread_id) do
      nil -> {:error, :not_found}
      thread -> thread |> Ecto.Changeset.change(is_pinned: false) |> Repo.update()
    end
  end

  def archive_thread(thread_id, archive_forum_slug) do
    case Repo.get(Thread, thread_id) do
      nil ->
        {:error, :not_found}

      thread ->
        archive_forum =
          case get_forum_by_slug(archive_forum_slug) do
            nil ->
              %Forum{}
              |> Forum.changeset(%{
                name: "Archive",
                slug: archive_forum_slug,
                description: "Archived threads"
              })
              |> Repo.insert!()

            f ->
              f
          end

        thread
        |> Ecto.Changeset.change(forum_id: archive_forum.id, is_locked: true, status: "archived")
        |> Repo.update()
    end
  end

  def feature_thread(thread_id, _position, featured_until) do
    case Repo.get(Thread, thread_id) do
      nil ->
        {:error, :not_found}

      thread ->
        until =
          case featured_until do
            v when is_binary(v) and v != "" ->
              case DateTime.from_iso8601(v) do
                {:ok, dt, _} -> DateTime.truncate(dt, :second)
                _ -> nil
              end

            _ ->
              nil
          end

        new_tags = Enum.uniq(["featured" | thread.tags || []])

        thread
        |> Ecto.Changeset.change(tags: new_tags, is_pinned: true, auto_close_at: until)
        |> Repo.update()
    end
  end

  def update_thread_prefix(thread_id, prefix) do
    case Repo.get(Thread, thread_id) do
      nil -> {:error, :not_found}
      thread -> thread |> Ecto.Changeset.change(prefix: prefix) |> Repo.update()
    end
  end

  def edit_thread_fields(thread_id, attrs) when is_map(attrs) do
    case Repo.get(Thread, thread_id) do
      nil -> {:error, :not_found}
      thread -> thread |> Thread.changeset(attrs) |> Repo.update()
    end
  end

  def split_posts_into_new_thread(post_ids, new_thread_title, forum_id) when is_list(post_ids) do
    Repo.transaction(fn ->
      first_post =
        case post_ids do
          [pid | _] -> Repo.get(Post, pid)
          _ -> nil
        end

      target_forum_id = forum_id || (first_post && first_post.forum_id)
      author_id = first_post && first_post.user_id

      slug =
        new_thread_title
        |> to_string()
        |> String.downcase()
        |> String.replace(~r/[^a-z0-9]+/, "-")
        |> String.trim("-")

      thread_attrs = %{
        title: new_thread_title,
        slug: slug,
        forum_id: target_forum_id,
        user_id: author_id,
        last_post_at: DateTime.utc_now() |> DateTime.truncate(:second)
      }

      thread = %Thread{} |> Thread.changeset(thread_attrs) |> Repo.insert!()

      {moved, _} =
        from(p in Post, where: p.id in ^post_ids)
        |> Repo.update_all(set: [thread_id: thread.id])

      %{thread: thread, moved: moved}
    end)
  end

  def set_forum_slow_mode(forum_id, seconds) when is_integer(seconds) do
    case Repo.get(Forum, forum_id) do
      nil ->
        {:error, :not_found}

      forum ->
        perms = forum.permissions || %{}
        new_perms = Map.put(perms, "slow_mode_seconds", seconds)
        forum |> Ecto.Changeset.change(permissions: new_perms) |> Repo.update()
    end
  end

  def detect_trending_threads(hours, limit) do
    cutoff = DateTime.utc_now() |> DateTime.add(-hours * 3600, :second)

    from(t in Thread,
      where: t.last_post_at >= ^cutoff and t.is_hidden == false,
      order_by: [desc: t.reply_count, desc: t.view_count],
      limit: ^limit,
      select: %{
        id: t.id,
        title: t.title,
        reply_count: t.reply_count,
        view_count: t.view_count
      }
    )
    |> Repo.all()
  end

  def thread_engagement_metrics(thread_id) do
    case Repo.get(Thread, thread_id) do
      nil ->
        %{
          views: 0,
          replies: 0,
          reactions: 0,
          unique_participants: 0,
          avg_response_time_hours: 0.0
        }

      thread ->
        reactions =
          from(r in Reaction,
            join: p in Post,
            on: p.id == r.post_id,
            where: p.thread_id == ^thread_id,
            select: count(r.id)
          )
          |> Repo.one() || 0

        unique_participants =
          from(p in Post,
            where: p.thread_id == ^thread_id,
            select: count(p.user_id, :distinct)
          )
          |> Repo.one() || 0

        avg_hours =
          case from(p in Post,
                 where: p.thread_id == ^thread_id,
                 order_by: [asc: p.inserted_at],
                 limit: 2,
                 select: p.inserted_at
               )
               |> Repo.all() do
            [first, second | _] ->
              Float.round(NaiveDateTime.diff(second, first) / 3600.0, 2)

            _ ->
              0.0
          end

        %{
          views: thread.view_count || 0,
          replies: thread.reply_count || 0,
          reactions: reactions,
          unique_participants: unique_participants,
          avg_response_time_hours: avg_hours
        }
    end
  end

  def user_activity_metrics(user_id, period_days) do
    cutoff = DateTime.utc_now() |> DateTime.add(-period_days * 86_400, :second)

    posts =
      from(p in Post,
        where: p.user_id == ^user_id and p.inserted_at >= ^cutoff,
        select: count(p.id)
      )
      |> Repo.one() || 0

    threads =
      from(t in Thread,
        where: t.user_id == ^user_id and t.inserted_at >= ^cutoff,
        select: count(t.id)
      )
      |> Repo.one() || 0

    reactions_given =
      from(r in Reaction,
        where: r.user_id == ^user_id and r.inserted_at >= ^cutoff,
        select: count(r.id)
      )
      |> Repo.one() || 0

    reactions_received =
      from(r in Reaction,
        join: p in Post,
        on: p.id == r.post_id,
        where: p.user_id == ^user_id and r.inserted_at >= ^cutoff,
        select: count(r.id)
      )
      |> Repo.one() || 0

    %{
      posts: posts,
      threads: threads,
      reactions_given: reactions_given,
      reactions_received: reactions_received,
      logins: ForgeNexus.Accounts.count_logins(user_id, period_days)
    }
  end

  def engagement_score(user_id, period_days) do
    %{posts: posts, threads: threads, reactions_given: rg, reactions_received: rr} =
      user_activity_metrics(user_id, period_days)

    post_score = min(50, posts * 2 + threads * 5)
    reaction_score = min(30, rg + rr * 2)
    visit_score = if posts > 0 or threads > 0, do: 20, else: 0
    score = min(100, post_score + reaction_score + visit_score)

    %{
      score: score,
      breakdown: %{
        post_score: post_score,
        reaction_score: reaction_score,
        visit_score: visit_score
      }
    }
  end

  def growth_metrics(period_days) do
    cutoff = DateTime.utc_now() |> DateTime.add(-period_days * 86_400, :second)

    new_users =
      from(u in ForgeNexus.Accounts.User,
        where: u.inserted_at >= ^cutoff,
        select: count(u.id)
      )
      |> Repo.one() || 0

    new_threads =
      from(t in Thread, where: t.inserted_at >= ^cutoff, select: count(t.id))
      |> Repo.one() || 0

    new_posts =
      from(p in Post, where: p.inserted_at >= ^cutoff, select: count(p.id))
      |> Repo.one() || 0

    active_users =
      from(p in Post,
        where: p.inserted_at >= ^cutoff,
        select: count(p.user_id, :distinct)
      )
      |> Repo.one() || 0

    %{
      new_users: new_users,
      new_threads: new_threads,
      new_posts: new_posts,
      active_users: active_users
    }
  end

  def compare_metric_periods(metric, period_days, _compare_to) do
    now = DateTime.utc_now()
    p1_start = DateTime.add(now, -period_days * 86_400, :second)
    p2_start = DateTime.add(p1_start, -period_days * 86_400, :second)

    current = count_metric(metric, p1_start, now)
    previous = count_metric(metric, p2_start, p1_start)

    change_percent =
      cond do
        previous == 0 and current == 0 -> 0.0
        previous == 0 -> 100.0
        true -> Float.round((current - previous) / previous * 100, 1)
      end

    trend =
      cond do
        change_percent > 0 -> "up"
        change_percent < 0 -> "down"
        true -> "flat"
      end

    %{current: current, previous: previous, change_percent: change_percent, trend: trend}
  end

  defp count_metric("posts", from_dt, to_dt) do
    from(p in Post,
      where: p.inserted_at >= ^from_dt and p.inserted_at < ^to_dt,
      select: count(p.id)
    )
    |> Repo.one() || 0
  end

  defp count_metric("threads", from_dt, to_dt) do
    from(t in Thread,
      where: t.inserted_at >= ^from_dt and t.inserted_at < ^to_dt,
      select: count(t.id)
    )
    |> Repo.one() || 0
  end

  defp count_metric("users", from_dt, to_dt) do
    from(u in ForgeNexus.Accounts.User,
      where: u.inserted_at >= ^from_dt and u.inserted_at < ^to_dt,
      select: count(u.id)
    )
    |> Repo.one() || 0
  end

  defp count_metric("active_users", from_dt, to_dt) do
    from(p in Post,
      where: p.inserted_at >= ^from_dt and p.inserted_at < ^to_dt,
      select: count(p.user_id, :distinct)
    )
    |> Repo.one() || 0
  end

  defp count_metric(_, _, _), do: 0

  def detect_churn_risk_users(inactive_days, min_previous_activity) do
    cutoff = DateTime.utc_now() |> DateTime.add(-inactive_days * 86_400, :second)

    from(p in Post,
      group_by: p.user_id,
      having: count(p.id) >= ^min_previous_activity,
      having: max(p.inserted_at) < ^cutoff,
      select: %{
        user_id: p.user_id,
        last_post_at: max(p.inserted_at),
        post_count: count(p.id)
      }
    )
    |> Repo.all()
  end
end
