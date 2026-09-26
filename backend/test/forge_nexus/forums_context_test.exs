defmodule ForgeNexus.ForumsContextTest do
  use ForgeNexus.DataCase, async: false

  alias ForgeNexus.Forums

  alias ForgeNexus.Forums.{
    Badge,
    ThreadPrefix,
    CustomBBCode,
    ForumWebhook
  }

  alias ForgeNexus.Accounts

  defp insert_user!(attrs \\ %{}) do
    n = System.unique_integer([:positive])

    default = %{
      username: "forum_ctx_#{n}",
      slug: "forum-ctx-#{n}",
      email: "forum_ctx_#{n}@example.com",
      password: "Fn9#xK8$mQ2!wZ7^vL4*",
      display_name: "Forum User #{n}",
      status: "active"
    }

    {:ok, user} = Accounts.register_user(Map.merge(default, attrs))
    user
  end

  defp create_category_and_forum do
    n = System.unique_integer([:positive])

    {:ok, cat} =
      Forums.create_category(%{
        name: "Category #{n}",
        slug: "category-#{n}",
        position: 1
      })

    {:ok, forum} =
      Forums.create_forum(%{
        name: "Forum #{n}",
        slug: "forum-#{n}",
        category_id: cat.id,
        position: 1
      })

    {cat, forum}
  end

  defp create_thread_with_post(user, forum, attrs \\ %{}) do
    n = System.unique_integer([:positive])

    default = %{
      title: "Thread #{n}",
      body: "Initial post body #{n}",
      forum_id: forum.id,
      user_id: user.id
    }

    {:ok, thread} = Forums.create_thread(Map.merge(default, attrs))
    thread
  end

  # =========================================================================
  # Categories and Forums
  # =========================================================================
  describe "categories and forums extended" do
    test "get_category!, get_category_by_slug!, get_forum!, get_forum_by_slug!" do
      {cat, forum} = create_category_and_forum()

      assert Forums.get_category!(cat.id).id == cat.id
      assert Forums.get_category_by_slug!(cat.slug).id == cat.id
      assert Forums.get_forum!(forum.id).id == forum.id
      assert Forums.get_forum_by_slug(forum.slug).id == forum.id
      assert Forums.get_forum_by_slug!(forum.slug).id == forum.id
      assert Enum.any?(Forums.list_forums(), &(&1.id == forum.id))
    end

    test "set_forum_slow_mode/2 updates slow mode permissions" do
      {_cat, forum} = create_category_and_forum()

      assert {:ok, updated} = Forums.set_forum_slow_mode(forum.id, 30)
      assert updated.permissions["slow_mode_seconds"] == 30

      assert Forums.set_forum_slow_mode(Ecto.UUID.generate(), 30) == {:error, :not_found}
    end
  end

  # =========================================================================
  # Threads and Posts
  # =========================================================================
  describe "thread lifecycle & operations" do
    setup do
      user = insert_user!()
      {cat, forum} = create_category_and_forum()
      %{user: user, cat: cat, forum: forum}
    end

    test "update_thread, increment_view_count, get_thread!, get_thread_by_slug!", %{
      user: user,
      forum: forum
    } do
      thread = create_thread_with_post(user, forum)

      assert {:ok, updated} = Forums.update_thread(thread, %{is_locked: true})
      assert updated.is_locked == true

      assert {1, _} = Forums.increment_view_count(thread)
      reloaded = Forums.get_thread!(thread.id)
      assert reloaded.view_count == 1

      by_slug = Forums.get_thread_by_slug!(thread.slug)
      assert by_slug.id == thread.id
      assert Forums.get_thread_by_id!(thread.id).id == thread.id
    end

    test "update_post creates audit PostEdit record and converts BBCode", %{
      user: user,
      forum: forum
    } do
      thread = create_thread_with_post(user, forum)
      [post] = Forums.list_posts(thread.id)

      assert {:ok, updated} =
               Forums.update_post(post, %{
                 body: "[b]Updated bold[/b]",
                 edit_reason: "Fix typo"
               })

      assert updated.body == "[b]Updated bold[/b]"
      assert updated.body_html =~ "<strong>Updated bold</strong>"
      assert updated.is_edited == true

      edits = Forums.list_post_edits(post.id)
      assert length(edits) == 1
      [edit] = edits
      assert edit.body_before == post.body
      assert edit.body_after == "[b]Updated bold[/b]"
      assert edit.reason == "Fix typo"

      assert {:ok, mod_updated} = Forums.mod_update_post(updated, %{is_hidden: true})
      assert mod_updated.is_hidden == true
    end

    test "merge_threads moves posts and hides source thread", %{user: user, forum: forum} do
      t1 = create_thread_with_post(user, forum, %{title: "Source Thread"})
      t2 = create_thread_with_post(user, forum, %{title: "Target Thread"})

      # Add a reply to t1
      {:ok, reply} = Forums.create_post(%{thread_id: t1.id, user_id: user.id, body: "T1 reply"})

      assert {:ok, merged_target} = Forums.merge_threads(t1.id, t2.id)
      assert merged_target.id == t2.id

      # Source thread is now hidden and merged_into t2
      reloaded_t1 = Forums.get_thread!(t1.id)
      assert reloaded_t1.is_hidden == true
      assert reloaded_t1.merged_into_id == t2.id

      # Reply post now belongs to t2 with merged_from_thread_id
      reloaded_reply = Forums.get_post!(reply.id)
      assert reloaded_reply.thread_id == t2.id
      assert reloaded_reply.merged_from_thread_id == t1.id
    end

    test "create_poll creates poll and poll options", %{user: user, forum: forum} do
      thread = create_thread_with_post(user, forum)

      assert {:ok, poll} =
               Forums.create_poll(
                 %{
                   question: "Favorite Language?",
                   thread_id: thread.id,
                   user_id: user.id
                 },
                 ["Elixir", "Rust", "Go"]
               )

      assert poll.question == "Favorite Language?"
      assert length(poll.options) == 3
      assert Enum.map(poll.options, & &1.text) == ["Elixir", "Rust", "Go"]
    end

    test "mark_solved and unmark_solved updates thread", %{user: user, forum: forum} do
      thread = create_thread_with_post(user, forum)

      {:ok, answer} =
        Forums.create_post(%{thread_id: thread.id, user_id: user.id, body: "Here is the fix"})

      assert {:ok, solved} = Forums.mark_solved(thread.id, answer.id)
      assert solved.is_solved == true
      assert solved.solved_post_id == answer.id

      assert {:ok, unsolved} = Forums.unmark_solved(thread.id)
      assert unsolved.is_solved == false
      assert unsolved.solved_post_id == nil
    end

    test "pin_thread, unpin_thread, pin_target, unpin_target", %{user: user, forum: forum} do
      thread = create_thread_with_post(user, forum)

      assert {:ok, pinned} = Forums.pin_thread(thread.id)
      assert pinned.is_pinned == true

      assert {:ok, unpinned} = Forums.unpin_thread(thread.id)
      assert unpinned.is_pinned == false

      assert {:ok, _} = Forums.pin_target("thread", thread.id)
      assert {:ok, _} = Forums.unpin_target("thread", thread.id)
      assert Forums.pin_target("invalid", thread.id) == {:error, :unsupported_target}
      assert Forums.unpin_target("invalid", thread.id) == {:error, :unsupported_target}
    end

    test "archive_thread, feature_thread, update_thread_prefix, edit_thread_fields", %{
      user: user,
      forum: forum
    } do
      thread = create_thread_with_post(user, forum)

      # Create archive forum
      {:ok, archive_forum} =
        Forums.create_forum(%{
          name: "Archive",
          slug: "archive-forum-#{System.unique_integer([:positive])}",
          category_id: forum.category_id
        })

      assert {:ok, archived} = Forums.archive_thread(thread.id, archive_forum.slug)
      assert archived.forum_id == archive_forum.id
      assert archived.status == "archived"
      assert archived.is_locked == true

      # Feature thread
      assert {:ok, featured} = Forums.feature_thread(thread.id, 1, nil)
      assert "featured" in featured.tags
      assert featured.is_pinned == true

      # Update thread prefix string
      assert {:ok, prefixed} = Forums.update_thread_prefix(thread.id, "GUIDE")
      assert prefixed.prefix == "GUIDE"

      # Edit thread fields
      assert {:ok, edited} = Forums.edit_thread_fields(thread.id, %{title: "New Title Here"})
      assert edited.title == "New Title Here"
    end

    test "split_posts_into_new_thread moves selected posts into a fresh thread", %{
      user: user,
      forum: forum
    } do
      thread = create_thread_with_post(user, forum)
      {:ok, p1} = Forums.create_post(%{thread_id: thread.id, user_id: user.id, body: "Split 1"})
      {:ok, p2} = Forums.create_post(%{thread_id: thread.id, user_id: user.id, body: "Split 2"})

      assert {:ok, %{thread: new_th, moved: 2}} =
               Forums.split_posts_into_new_thread([p1.id, p2.id], "Offtopic Discussion", forum.id)

      assert new_th.title == "Offtopic Discussion"
      assert Forums.get_post!(p1.id).thread_id == new_th.id
      assert Forums.get_post!(p2.id).thread_id == new_th.id
    end
  end

  # =========================================================================
  # Post Ratings and Reactions
  # =========================================================================
  describe "post ratings and emoji reactions" do
    setup do
      u1 = insert_user!()
      u2 = insert_user!()
      {_cat, forum} = create_category_and_forum()
      thread = create_thread_with_post(u1, forum)
      [post] = Forums.list_posts(thread.id)
      %{u1: u1, u2: u2, post: post}
    end

    test "rate_post handles self-rating guard, rating, toggle, and summaries", %{
      u1: u1,
      u2: u2,
      post: post
    } do
      # Self-rating guard
      assert Forums.rate_post(post.id, u1.id, "like") == {:error, :self_rating}

      # Rate post
      assert {:ok, _rating} = Forums.rate_post(post.id, u2.id, "like")
      ratings = Forums.get_post_ratings(post.id)
      assert Enum.any?(ratings, fn r -> r.type == "like" and r.count == 1 end)

      user_ratings = Forums.get_user_ratings_for_post(post.id, u2.id)
      assert "like" in user_ratings

      summary = Forums.user_rating_summary(u1.id)
      assert summary["like"] == 1

      # Toggle off (second rate_post deletes existing)
      assert {:ok, _deleted} = Forums.rate_post(post.id, u2.id, "like")
      assert Forums.get_user_ratings_for_post(post.id, u2.id) == []
    end

    test "toggle_reaction handles self-reaction guard, toggle, counts, and popular reactions", %{
      u1: u1,
      u2: u2,
      post: post
    } do
      # Self-reaction guard
      assert Forums.toggle_reaction(post.id, u1.id, "thanks") == {:error, :self_reaction}

      # Add reaction
      assert {:ok, _rx} = Forums.toggle_reaction(post.id, u2.id, "thanks")
      assert length(Forums.list_reactions(post.id)) == 1
      assert Forums.reaction_counts(post.id)["thanks"] == 1
      assert Forums.user_reactions_for_post(post.id, u2.id) == ["thanks"]

      counts_map = Forums.reaction_counts_for_posts([post.id])
      assert Map.has_key?(counts_map, post.id)

      user_map = Forums.user_reactions_for_posts([post.id], u2.id)
      assert user_map[post.id] == ["thanks"]

      refute Forums.post_has_popular_reaction?(post.id, 5)

      # Toggle off
      assert {:ok, _del} = Forums.toggle_reaction(post.id, u2.id, "thanks")
      assert Forums.list_reactions(post.id) == []
    end
  end

  # =========================================================================
  # Badges
  # =========================================================================
  describe "badges management" do
    test "badge CRUD, award, feature, and auto badges" do
      user = insert_user!(%{post_count: 50, thread_count: 10, reputation: 100})
      n = System.unique_integer([:positive])

      assert {:ok, %Badge{} = badge} =
               Forums.create_badge(%{
                 name: "Century Poster #{n}",
                 slug: "century-poster-#{n}",
                 description: "Created 10 threads",
                 is_auto: true,
                 is_active: true,
                 auto_criteria: %{"type" => "thread_count", "value" => 10}
               })

      assert Forums.get_badge!(badge.id).id == badge.id
      assert Enum.any?(Forums.list_badges(), &(&1.id == badge.id))
      assert Enum.any?(Forums.list_all_badges(), &(&1.id == badge.id))

      assert {:ok, updated} = Forums.update_badge(badge.id, %{description: "Updated description"})
      assert updated.description == "Updated description"

      # Award badge
      assert {:ok, _ub} = Forums.award_badge(user.id, badge.id)
      user_b = Forums.user_badges(user.id)
      assert Enum.any?(user_b, &(&1.badge_id == badge.id))

      # Feature badge
      assert {:ok, feat} = Forums.feature_badge(user.id, badge.id, true)
      assert feat.is_featured == true

      # Check auto badges
      Forums.check_auto_badges(user)

      # Revoke badge
      assert {:ok, _} = Forums.revoke_badge(user.id, badge.id)
      refute Enum.any?(Forums.user_badges(user.id), &(&1.badge_id == badge.id))

      # Delete badge
      assert {:ok, _} = Forums.delete_badge(badge.id)
    end
  end

  # =========================================================================
  # Prefixes, Drafts, and Ignores
  # =========================================================================
  describe "prefixes, drafts, and ignores" do
    setup do
      user = insert_user!()
      {_cat, forum} = create_category_and_forum()
      thread = create_thread_with_post(user, forum)
      %{user: user, forum: forum, thread: thread}
    end

    test "thread prefixes CRUD and setting on thread", %{forum: forum, thread: thread} do
      n = System.unique_integer([:positive])

      assert {:ok, %ThreadPrefix{} = p} =
               Forums.create_prefix(%{
                 name: "Tutorial #{n}",
                 color: "#4CAF50",
                 forum_id: forum.id
               })

      assert Enum.any?(Forums.list_prefixes_for_forum(forum.id), &(&1.id == p.id))
      assert Enum.any?(Forums.list_prefixes(forum.id), &(&1.id == p.id))
      assert Enum.any?(Forums.list_all_prefixes(), &(&1.id == p.id))

      assert {:ok, _} = Forums.set_thread_prefix(thread.id, p.id)
      assert Forums.get_thread!(thread.id).prefix == p.name

      assert {:ok, updated} = Forums.update_prefix(p.id, %{name: "Updated #{n}"})
      assert updated.name == "Updated #{n}"

      assert {:ok, _} = Forums.delete_prefix(p.id)
    end

    test "drafts save, get, update, and delete", %{user: user} do
      assert {:ok, draft} =
               Forums.save_draft(user.id, "thread_create", "general", "Draft content", "My Title")

      assert draft.body == "Draft content"

      got = Forums.get_draft(user.id, "thread_create", "general")
      assert got.id == draft.id

      # Update draft
      assert {:ok, updated} =
               Forums.save_draft(user.id, "thread_create", "general", "Updated draft content")

      assert updated.body == "Updated draft content"

      assert {:ok, _} = Forums.delete_draft(user.id, "thread_create", "general")
      assert Forums.get_draft(user.id, "thread_create", "general") == nil
    end

    test "content ignores for forum and thread", %{user: user, forum: forum, thread: thread} do
      assert {:ok, _} = Forums.ignore_forum(user.id, forum.id)
      assert forum.id in Forums.ignored_forum_ids(user.id)

      assert {:ok, _} = Forums.ignore_thread(user.id, thread.id)
      assert thread.id in Forums.ignored_thread_ids(user.id)

      ignores = Forums.list_ignores(user.id)
      assert length(ignores) == 2

      assert {:ok, _} = Forums.unignore_forum(user.id, forum.id)
      refute forum.id in Forums.ignored_forum_ids(user.id)

      assert {:ok, _} = Forums.unignore_thread(user.id, thread.id)
      refute thread.id in Forums.ignored_thread_ids(user.id)
    end
  end

  # =========================================================================
  # Read Status, Subscriptions, Bookmarks, and Ratings
  # =========================================================================
  describe "read status, subscriptions, and bookmarks" do
    setup do
      user = insert_user!()
      {_cat, forum} = create_category_and_forum()
      thread = create_thread_with_post(user, forum)
      [post] = Forums.list_posts(thread.id)
      %{user: user, forum: forum, thread: thread, post: post}
    end

    test "thread read tracking and unread counts", %{user: user, forum: forum, thread: thread} do
      assert {:ok, _} = Forums.mark_thread_read(thread.id, user.id)
      threads_with_read = Forums.list_threads_with_read_status(forum.id, user.id)
      assert length(threads_with_read) >= 1
      assert hd(threads_with_read).has_unread == false

      assert :ok = Forums.mark_forum_read(forum.id, user.id)
      unreads = Forums.unread_counts_by_forum(user.id)
      assert is_map(unreads)
    end

    test "thread ratings stats and user ratings", %{user: user, thread: thread} do
      assert {:ok, _} = Forums.rate_thread(thread.id, user.id, 5)
      stats = Forums.get_thread_rating_stats(thread.id)
      assert stats.count == 1
      assert stats.average == 5.0

      user_r = Forums.get_user_thread_rating(thread.id, user.id)
      assert user_r.rating == 5
    end

    test "thread subscriptions subscribe, get, and unsubscribe", %{user: user, thread: thread} do
      assert {:ok, _sub} = Forums.subscribe_thread(thread.id, user.id, "watching")
      sub = Forums.get_thread_subscription(thread.id, user.id)
      assert sub.notification_level == "watching"

      assert {:ok, _} = Forums.unsubscribe_thread(thread.id, user.id)
      assert Forums.get_thread_subscription(thread.id, user.id) == nil
    end

    test "post bookmarks toggle, list, and query", %{user: user, post: post} do
      refute Forums.is_post_bookmarked?(user.id, post.id)

      assert {:ok, _} = Forums.toggle_post_bookmark(user.id, post.id, "Remember this")
      assert Forums.is_post_bookmarked?(user.id, post.id)
      assert MapSet.member?(Forums.post_bookmark_ids(user.id), post.id)

      bookmarks = Forums.list_post_bookmarks(user.id)
      assert length(bookmarks) == 1

      # Toggle off
      assert {:ok, _} = Forums.toggle_post_bookmark(user.id, post.id)
      refute Forums.is_post_bookmarked?(user.id, post.id)
    end
  end

  # =========================================================================
  # Mentions, Quotes, Webhooks, BBCodes, and Permissions
  # =========================================================================
  describe "mentions, quotes, webhooks, and permissions" do
    test "detect_mentions and detect_quotes parse usernames correctly" do
      text =
        "Hello @alice and @bob! Also [quote=\"charlie\"]Check this[/quote] and [quote=david]neat[/quote]"

      assert Forums.detect_mentions(text) == ["alice", "bob"]
      assert Forums.detect_quotes(text) == ["charlie", "david"]
      assert Forums.detect_mentions(nil) == []
      assert Forums.detect_quotes(nil) == []
    end

    test "custom bbcode CRUD" do
      n = System.unique_integer([:positive])

      assert {:ok, %CustomBBCode{} = bb} =
               Forums.create_custom_bbcode(%{
                 tag_name: "custom_#{n}",
                 replacement_html: "<span class=\"custom\">{param}</span>",
                 description: "Custom tag",
                 is_active: true
               })

      assert Enum.any?(Forums.list_custom_bbcodes(), &(&1.id == bb.id))
      assert Enum.any?(Forums.list_active_custom_bbcodes(), &(&1.id == bb.id))

      assert {:ok, updated} = Forums.update_custom_bbcode(bb.id, %{description: "New desc"})
      assert updated.description == "New desc"

      assert {:ok, _} = Forums.delete_custom_bbcode(bb.id)
      assert Forums.update_custom_bbcode(Ecto.UUID.generate(), %{}) == {:error, :not_found}
    end

    test "forum webhook CRUD and deliveries" do
      {_cat, forum} = create_category_and_forum()

      assert {:ok, %ForumWebhook{} = wh} =
               Forums.create_forum_webhook(%{
                 name: "Discord Alert",
                 url: "https://discord.com/api/webhooks/test",
                 forum_id: forum.id,
                 events: ["forum.thread.created", "forum.post.created"],
                 is_active: true
               })

      assert Forums.get_forum_webhook!(wh.id).id == wh.id
      assert Forums.get_forum_webhook(wh.id).id == wh.id
      assert Enum.any?(Forums.list_forum_webhooks(), &(&1.id == wh.id))

      assert {:ok, _del} =
               Forums.record_webhook_delivery(%{
                 webhook_id: wh.id,
                 event_type: "forum.thread.created",
                 status_code: 200,
                 attempt: 1,
                 delivered_at: DateTime.utc_now() |> DateTime.truncate(:second)
               })

      assert length(Forums.list_webhook_deliveries(wh.id)) == 1

      assert :ok =
               Forums.fire_webhook_event("forum.thread.created", %{
                 thread_id: Ecto.UUID.generate()
               })

      assert {:ok, updated} = Forums.update_forum_webhook(wh.id, %{name: "Updated Webhook"})
      assert updated.name == "Updated Webhook"

      assert {:ok, _} = Forums.delete_forum_webhook(wh.id)
      assert Forums.get_forum_webhook(wh.id) == nil
    end

    test "forum permissions and thread participants" do
      user = insert_user!()
      other = insert_user!()
      {_cat, forum} = create_category_and_forum()
      thread = create_thread_with_post(user, forum, %{is_private: true})

      group =
        %ForgeNexus.Accounts.UserGroup{}
        |> ForgeNexus.Accounts.UserGroup.changeset(%{
          name: "VipGroup #{System.unique_integer([:positive])}"
        })
        |> Repo.insert!()

      assert {:ok, _p} =
               Forums.set_forum_permissions(forum.id, group.id, %{can_view: true, can_post: true})

      assert length(Forums.list_forum_permissions(forum.id)) == 1

      # Thread participants
      assert {:ok, _} = Forums.add_thread_participant(thread.id, other.id)
      participants = Forums.list_thread_participants(thread.id)
      assert Enum.any?(participants, &(&1.id == other.id))

      # can_view_thread? check
      assert Forums.can_view_thread?(thread, user)
      assert Forums.can_view_thread?(thread, other)

      random_user = insert_user!()
      refute Forums.can_view_thread?(thread, random_user)
      refute Forums.can_view_thread?(thread, nil)

      assert {:ok, _} = Forums.remove_thread_participant(thread.id, other.id)
      refute Enum.any?(Forums.list_thread_participants(thread.id), &(&1.id == other.id))
    end

    test "metrics, bulk actions, and statistics" do
      user = insert_user!()
      {_cat, forum} = create_category_and_forum()
      t1 = create_thread_with_post(user, forum)
      t2 = create_thread_with_post(user, forum)

      # Bulk actions
      assert :ok = Forums.bulk_update_threads([t1.id, t2.id], %{is_locked: true})
      assert Forums.get_thread!(t1.id).is_locked == true

      assert :ok = Forums.bulk_hide_threads([t1.id])
      assert Forums.get_thread!(t1.id).is_hidden == true

      # Metrics
      assert Forums.count_threads() >= 1
      assert Forums.count_posts() >= 1
      assert is_list(Forums.recent_threads(5))
      assert is_list(Forums.trending_threads("week"))
      assert is_integer(Forums.new_threads_this_month())
      assert is_integer(Forums.new_posts_this_month())
      assert is_list(Forums.most_popular_threads(5))
      assert is_list(Forums.monthly_thread_growth(6))
      assert is_list(Forums.monthly_post_growth(6))

      # Engagement and activity metrics
      metrics = Forums.thread_engagement_metrics(t2.id)
      assert is_map(metrics)

      u_metrics = Forums.user_activity_metrics(user.id, 30)
      assert is_map(u_metrics)

      score = Forums.engagement_score(user.id, 30)
      assert is_integer(score.score)

      growth = Forums.growth_metrics(30)
      assert is_map(growth)

      comparison = Forums.compare_metric_periods("posts", 30, "previous_period")
      assert is_map(comparison)

      churn = Forums.detect_churn_risk_users(30, 1)
      assert is_list(churn)
    end
  end
end
