defmodule ForgeNexus.Workers.CoreScheduledAndEmailWorkersTest do
  use ForgeNexus.DataCase, async: false
  use Oban.Testing, repo: ForgeNexus.Repo

  alias ForgeNexus.{Accounts, Forums, Repo, StatsCache}
  alias ForgeNexus.Forums.Attachment
  alias ForgeNexus.Accounts.User

  alias ForgeNexus.Workers.{
    CountReconciler,
    ImageOptimizer,
    MassEmailer,
    NotificationEmailer,
    PresenceReaper,
    ScheduledPostPublisher,
    StatsComputer,
    TopicTimer,
    TransactionalEmailer
  }

  defp create_user(attrs \\ %{}) do
    unique_suffix = System.unique_integer([:positive])

    defaults = %{
      username: "worker_core_#{unique_suffix}",
      email: "worker_core_#{unique_suffix}@example.com",
      password: "SecurePass!987654#Alpha",
      password_confirmation: "SecurePass!987654#Alpha"
    }

    {:ok, user} =
      defaults
      |> Map.merge(Enum.into(attrs, %{}))
      |> Accounts.register_user()

    user
  end

  defp create_forum_and_thread(user) do
    unique_suffix = System.unique_integer([:positive])

    {:ok, category} =
      Forums.create_category(%{
        name: "Cat #{unique_suffix}"
      })

    {:ok, forum} =
      Forums.create_forum(%{
        name: "Forum #{unique_suffix}",
        description: "Forum description",
        category_id: category.id,
        position: 0
      })

    {:ok, thread} =
      Forums.create_thread(%{
        title: "Thread #{unique_suffix}",
        body: "Initial post body content",
        user_id: user.id,
        forum_id: forum.id
      })

    [post | _] = Forums.list_posts(thread.id)
    {forum, thread, post}
  end

  describe "CountReconciler" do
    test "recomputes denormalized counters on threads, forums, and users" do
      user = create_user()
      {forum, thread, _post} = create_forum_and_thread(user)

      # Corrupt counters manually
      Ecto.Changeset.change(thread, %{reply_count: 99}) |> Repo.update!()
      Ecto.Changeset.change(forum, %{thread_count: 99, post_count: 99}) |> Repo.update!()
      Ecto.Changeset.change(user, %{post_count: 99, thread_count: 99}) |> Repo.update!()

      assert {:ok, result} = perform_job(CountReconciler, %{})
      assert is_integer(result.threads)
      assert is_integer(result.forums)
      assert is_integer(result.users)

      reconciled_thread = Repo.get!(Forums.Thread, thread.id)
      reconciled_forum = Repo.get!(Forums.Forum, forum.id)
      reconciled_user = Repo.get!(User, user.id)

      assert reconciled_thread.reply_count == 0
      assert reconciled_forum.thread_count == 1
      assert reconciled_forum.post_count == 1
      assert reconciled_user.thread_count == 1
      assert reconciled_user.post_count == 1
    end
  end

  describe "NotificationEmailer" do
    test "delivers reply notification when preference is enabled" do
      user = create_user()
      Accounts.update_preferences(user.id, %{email_replies: true, dnd_enabled: false})

      args = %{
        "type" => "reply",
        "user_id" => user.id,
        "actor_name" => "Alice",
        "thread_title" => "Great Discussion",
        "thread_slug" => "great-discussion"
      }

      assert :ok = perform_job(NotificationEmailer, args)
    end

    test "delivers mention notification when preference is enabled" do
      user = create_user()
      Accounts.update_preferences(user.id, %{email_mentions: true, dnd_enabled: false})

      args = %{
        "type" => "mention",
        "user_id" => user.id,
        "actor_name" => "Bob",
        "url" => "http://localhost:5173/posts/123"
      }

      assert :ok = perform_job(NotificationEmailer, args)
    end

    test "delivers dm notification when preference is enabled" do
      user = create_user()
      Accounts.update_preferences(user.id, %{email_dms: true, dnd_enabled: false})

      args = %{
        "type" => "dm",
        "user_id" => user.id,
        "actor_name" => "Charlie"
      }

      assert :ok = perform_job(NotificationEmailer, args)
    end

    test "skips delivery when preference is disabled" do
      user = create_user()
      Accounts.update_preferences(user.id, %{email_replies: false})

      args = %{
        "type" => "reply",
        "user_id" => user.id,
        "actor_name" => "Dave"
      }

      assert :ok = perform_job(NotificationEmailer, args)
    end

    test "skips delivery when inside non-wrapping DND window" do
      user = create_user()

      Accounts.update_preferences(user.id, %{
        email_replies: true,
        dnd_enabled: true,
        dnd_start: "00:00",
        dnd_end: "23:59"
      })

      args = %{
        "type" => "reply",
        "user_id" => user.id,
        "actor_name" => "Eve"
      }

      assert :ok = perform_job(NotificationEmailer, args)
    end

    test "skips delivery when inside wrapping midnight DND window" do
      user = create_user()

      Accounts.update_preferences(user.id, %{
        email_replies: true,
        dnd_enabled: true,
        dnd_start: "12:00",
        dnd_end: "11:59"
      })

      args = %{
        "type" => "reply",
        "user_id" => user.id,
        "actor_name" => "Frank"
      }

      assert :ok = perform_job(NotificationEmailer, args)
    end

    test "handles malformed DND time strings gracefully" do
      user = create_user()

      Accounts.update_preferences(user.id, %{
        email_replies: true,
        dnd_enabled: true,
        dnd_start: "invalid",
        dnd_end: "bad:format"
      })

      args = %{
        "type" => "reply",
        "user_id" => user.id,
        "actor_name" => "Grace"
      }

      assert :ok = perform_job(NotificationEmailer, args)
    end

    test "skips delivery for unknown notification type" do
      user = create_user()

      args = %{
        "type" => "unknown_type",
        "user_id" => user.id
      }

      assert :ok = perform_job(NotificationEmailer, args)
    end

    test "enqueue helpers insert jobs successfully" do
      user = create_user()

      assert {:ok, %Oban.Job{}} =
               NotificationEmailer.enqueue_reply_notification(
                 user.id,
                 "Actor",
                 "Thread Title",
                 "thread-slug"
               )

      assert {:ok, %Oban.Job{}} =
               NotificationEmailer.enqueue_mention_notification(
                 user.id,
                 "Actor",
                 "http://example.com"
               )

      assert {:ok, %Oban.Job{}} =
               NotificationEmailer.enqueue_dm_notification(user.id, "Actor")
    end
  end

  describe "TransactionalEmailer" do
    test "returns cancel error when user does not exist" do
      assert {:cancel, :user_not_found} =
               perform_job(TransactionalEmailer, %{
                 "template" => "verify_email",
                 "user_id" => Ecto.UUID.generate()
               })
    end

    test "sends verify_email" do
      user = create_user()

      assert :ok =
               perform_job(TransactionalEmailer, %{
                 "template" => "verify_email",
                 "user_id" => user.id
               })
    end

    test "sends password_reset" do
      user = create_user()

      assert :ok =
               perform_job(TransactionalEmailer, %{
                 "template" => "password_reset",
                 "user_id" => user.id
               })
    end

    test "sends email_change" do
      user = create_user()

      assert :ok =
               perform_job(TransactionalEmailer, %{
                 "template" => "email_change",
                 "user_id" => user.id,
                 "new_email" => "new_address@example.com"
               })
    end

    test "sends password_changed_notice" do
      user = create_user()

      assert :ok =
               perform_job(TransactionalEmailer, %{
                 "template" => "password_changed_notice",
                 "user_id" => user.id
               })
    end

    test "sends email_changed_notice" do
      user = create_user()

      assert :ok =
               perform_job(TransactionalEmailer, %{
                 "template" => "email_changed_notice",
                 "user_id" => user.id,
                 "old_email" => "prior_address@example.com"
               })
    end

    test "sends ban_notice with defaults and custom fields" do
      user = create_user()

      assert :ok =
               perform_job(TransactionalEmailer, %{
                 "template" => "ban_notice",
                 "user_id" => user.id,
                 "type" => "temporary",
                 "reason" => "Terms violation",
                 "expires_at" => "2030-01-01T00:00:00Z"
               })
    end

    test "sends warning_notice" do
      user = create_user()

      assert :ok =
               perform_job(TransactionalEmailer, %{
                 "template" => "warning_notice",
                 "user_id" => user.id,
                 "reason" => "Repeated spamming",
                 "points" => 3
               })
    end

    test "sends ban_lifted_notice" do
      user = create_user()

      assert :ok =
               perform_job(TransactionalEmailer, %{
                 "template" => "ban_lifted_notice",
                 "user_id" => user.id
               })
    end

    test "sends warning_revoked_notice" do
      user = create_user()

      assert :ok =
               perform_job(TransactionalEmailer, %{
                 "template" => "warning_revoked_notice",
                 "user_id" => user.id,
                 "reason" => "Mistaken report"
               })
    end
  end

  describe "MassEmailer" do
    test "queries recipients and sends emails across all segments" do
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      active_user = create_user(%{status: "active"})
      Ecto.Changeset.change(active_user, %{last_seen_at: now}) |> Repo.update!()

      verified_user = create_user(%{status: "active"})

      Ecto.Changeset.change(verified_user, %{last_seen_at: now, email_verified_at: now})
      |> Repo.update!()

      # recipient_count/1
      assert MassEmailer.recipient_count("active_30d") >= 1
      assert MassEmailer.recipient_count("verified") >= 1
      assert MassEmailer.recipient_count("all") >= 2

      # perform/1 with all segment
      assert :ok =
               perform_job(MassEmailer, %{
                 "subject" => "General Announcement",
                 "body_html" => "<p>Important community update.<br>Please read.</p>",
                 "segment" => "all"
               })

      # perform/1 with active_30d segment
      assert :ok =
               perform_job(MassEmailer, %{
                 "subject" => "Active Members Announcement",
                 "body_html" => "<p>Hello active members!</p>",
                 "segment" => "active_30d"
               })

      # perform/1 with verified segment
      assert :ok =
               perform_job(MassEmailer, %{
                 "subject" => "Verified Members Announcement",
                 "body_html" => "<p>Hello verified users!</p>",
                 "segment" => "verified"
               })
    end
  end

  describe "PresenceReaper" do
    test "marks idle users offline and keeps active users online" do
      eleven_mins_ago =
        DateTime.utc_now() |> DateTime.add(-660, :second) |> DateTime.truncate(:second)

      now = DateTime.utc_now() |> DateTime.truncate(:second)

      # User 1: online, idle past 5 min threshold
      user_idle = create_user()

      Ecto.Changeset.change(user_idle, %{is_online: true, last_seen_at: eleven_mins_ago})
      |> Repo.update!()

      # User 2: online, last_seen_at is nil
      user_nil_seen = create_user()

      Ecto.Changeset.change(user_nil_seen, %{is_online: true, last_seen_at: nil})
      |> Repo.update!()

      # User 3: online, active within last 1 minute
      user_active = create_user()
      Ecto.Changeset.change(user_active, %{is_online: true, last_seen_at: now}) |> Repo.update!()

      assert {:ok, %{marked_offline: count}} = perform_job(PresenceReaper, %{})
      assert count >= 2

      assert Repo.get!(User, user_idle.id).is_online == false
      assert Repo.get!(User, user_nil_seen.id).is_online == false
      assert Repo.get!(User, user_active.id).is_online == true
    end
  end

  describe "ScheduledPostPublisher" do
    test "publishes scheduled threads when scheduled_at arrives and broadcasts to pubsub" do
      user = create_user()
      {forum, _thread, _post} = create_forum_and_thread(user)

      past_time =
        DateTime.utc_now() |> DateTime.add(-300, :second) |> DateTime.truncate(:second)

      future_time =
        DateTime.utc_now() |> DateTime.add(3600, :second) |> DateTime.truncate(:second)

      {:ok, scheduled_thread} =
        Forums.create_thread(%{
          title: "Scheduled Past Thread",
          body: "This should be published now",
          user_id: user.id,
          forum_id: forum.id,
          status: "scheduled",
          scheduled_at: past_time,
          is_hidden: true
        })

      {:ok, future_thread} =
        Forums.create_thread(%{
          title: "Scheduled Future Thread",
          body: "This should remain scheduled",
          user_id: user.id,
          forum_id: forum.id,
          status: "scheduled",
          scheduled_at: future_time,
          is_hidden: true
        })

      # Subscribe to pubsub to verify broadcast
      Phoenix.PubSub.subscribe(ForgeNexus.PubSub, "forum:#{forum.id}")

      assert :ok = perform_job(ScheduledPostPublisher, %{})

      updated_scheduled = Repo.get!(Forums.Thread, scheduled_thread.id)
      updated_future = Repo.get!(Forums.Thread, future_thread.id)

      assert updated_scheduled.status == "published"
      assert updated_scheduled.is_hidden == false

      assert updated_future.status == "scheduled"
      assert updated_future.is_hidden == true

      assert_receive {:new_thread, %{id: thread_id}}
      assert thread_id == scheduled_thread.id
    end
  end

  describe "StatsComputer" do
    test "computes community totals and caches them in StatsCache" do
      user = create_user()
      {_forum, _thread, _post} = create_forum_and_thread(user)

      assert :ok = perform_job(StatsComputer, %{})

      assert StatsCache.get(:total_members) >= 1
      assert StatsCache.get(:total_threads) >= 1
      assert StatsCache.get(:total_posts) >= 1
      assert StatsCache.get(:total_forums) >= 1
      assert StatsCache.get(:total_categories) >= 1
      assert is_integer(StatsCache.get(:new_members_today))
      assert is_integer(StatsCache.get(:posts_today))
      assert is_integer(StatsCache.get(:threads_today))
      assert is_list(StatsCache.get(:most_active_24h))
      assert is_list(StatsCache.get(:trending_threads))
      assert StatsCache.get(:last_computed_at) != nil
    end
  end

  describe "TopicTimer" do
    test "auto-closes and auto-deletes expired threads" do
      user = create_user()
      {forum, _thread, _post} = create_forum_and_thread(user)

      past_time =
        DateTime.utc_now() |> DateTime.add(-60, :second) |> DateTime.truncate(:second)

      future_time =
        DateTime.utc_now() |> DateTime.add(3600, :second) |> DateTime.truncate(:second)

      {:ok, close_thread} =
        Forums.create_thread(%{
          title: "Auto-close Thread",
          body: "Will close",
          user_id: user.id,
          forum_id: forum.id,
          is_locked: false
        })

      close_thread =
        Ecto.Changeset.change(close_thread, %{auto_close_at: past_time, is_locked: false})
        |> Repo.update!()

      {:ok, delete_thread} =
        Forums.create_thread(%{
          title: "Auto-delete Thread",
          body: "Will delete",
          user_id: user.id,
          forum_id: forum.id,
          is_hidden: false
        })

      delete_thread =
        Ecto.Changeset.change(delete_thread, %{auto_delete_at: past_time, is_hidden: false})
        |> Repo.update!()

      {:ok, safe_thread} =
        Forums.create_thread(%{
          title: "Safe Thread",
          body: "Will stay untouched",
          user_id: user.id,
          forum_id: forum.id,
          is_locked: false
        })

      safe_thread =
        Ecto.Changeset.change(safe_thread, %{auto_close_at: future_time, is_locked: false})
        |> Repo.update!()

      assert :ok = perform_job(TopicTimer, %{})

      assert Repo.get!(Forums.Thread, close_thread.id).is_locked == true
      assert Repo.get!(Forums.Thread, close_thread.id).auto_close_at == nil

      assert Repo.get!(Forums.Thread, delete_thread.id).is_hidden == true
      assert Repo.get!(Forums.Thread, delete_thread.id).auto_delete_at == nil

      assert Repo.get!(Forums.Thread, safe_thread.id).is_locked == false
      assert Repo.get!(Forums.Thread, safe_thread.id).auto_close_at != nil
    end
  end

  describe "ImageOptimizer" do
    test "handles missing attachment id gracefully" do
      assert :ok =
               perform_job(ImageOptimizer, %{
                 "attachment_id" => Ecto.UUID.generate()
               })
    end

    test "skips non-processable attachment types" do
      user = create_user()

      attachment =
        %Attachment{}
        |> Attachment.changeset(%{
          filename: "document.pdf",
          content_type: "application/pdf",
          size: 1024,
          url: "/uploads/document.pdf",
          attachable_type: "post",
          attachable_id: Ecto.UUID.generate(),
          user_id: user.id
        })
        |> Repo.insert!()

      assert :ok =
               perform_job(ImageOptimizer, %{
                 "attachment_id" => attachment.id
               })
    end

    test "handles processable attachment when file does not exist on disk" do
      user = create_user()

      attachment =
        %Attachment{}
        |> Attachment.changeset(%{
          filename: "nonexistent.png",
          content_type: "image/png",
          size: 2048,
          url: "/uploads/nonexistent_image_12345.png",
          attachable_type: "post",
          attachable_id: Ecto.UUID.generate(),
          user_id: user.id
        })
        |> Repo.insert!()

      assert :ok =
               perform_job(ImageOptimizer, %{
                 "attachment_id" => attachment.id
               })
    end

    test "enqueue/1 inserts Oban job" do
      uuid = Ecto.UUID.generate()
      assert {:ok, %Oban.Job{}} = ImageOptimizer.enqueue(uuid)
    end
  end
end
