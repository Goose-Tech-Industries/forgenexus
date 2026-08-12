defmodule ForgeNexus.AffiliateTest do
  use ForgeNexus.DataCase, async: true

  alias ForgeNexus.Affiliate
  alias ForgeNexus.Accounts.{User, UserFollow}
  alias ForgeNexus.Forums.{Category, Forum, Thread, Post}
  alias ForgeNexus.Voice.CallLog

  describe "progress/1 — followers (the followee_id/followed_id bug)" do
    test "counts UserFollow rows where this user is the one being followed" do
      creator = insert_user!()
      insert_follow!(insert_user!(), creator)
      insert_follow!(insert_user!(), creator)
      insert_follow!(insert_user!(), creator)

      # A follow going the OTHER way (creator follows someone else) must not
      # count towards creator's own follower total.
      insert_follow!(creator, insert_user!())

      progress = Affiliate.progress(creator)
      assert progress.followers.current == 3
      assert progress.followers.target == 50
      assert progress.followers.met == false
    end

    test "met becomes true once the follower target is reached" do
      creator = insert_user!()
      for _ <- 1..50, do: insert_follow!(insert_user!(), creator)

      assert Affiliate.progress(creator).followers.met == true
    end
  end

  describe "progress/1 — days active" do
    test "counts distinct calendar days across posts, threads, and hosted voice sessions" do
      creator = insert_user!()
      forum = insert_forum!()

      insert_post!(creator, forum, inserted_at: ~U[2026-01-01 10:00:00Z])
      # same day, second post -- should not double count
      insert_post!(creator, forum, inserted_at: ~U[2026-01-01 22:00:00Z])
      insert_thread!(creator, forum, inserted_at: ~U[2026-01-02 09:00:00Z])

      insert_call_log!(creator,
        started_at: ~U[2026-01-03 09:00:00Z],
        ended_at: ~U[2026-01-03 10:00:00Z]
      )

      assert Affiliate.progress(creator).days_active.current == 3
    end

    test "hidden posts and threads don't count towards active days" do
      creator = insert_user!()
      forum = insert_forum!()

      insert_post!(creator, forum, inserted_at: ~U[2026-01-01 10:00:00Z], is_hidden: true)
      insert_thread!(creator, forum, inserted_at: ~U[2026-01-02 10:00:00Z], is_hidden: true)

      assert Affiliate.progress(creator).days_active.current == 0
    end

    test "other users' activity doesn't count towards this creator's days" do
      creator = insert_user!()
      someone_else = insert_user!()
      forum = insert_forum!()

      insert_post!(someone_else, forum, inserted_at: ~U[2026-01-01 10:00:00Z])

      assert Affiliate.progress(creator).days_active.current == 0
    end
  end

  describe "progress/1 — stream minutes" do
    test "sums minutes across completed voice sessions hosted by this user" do
      creator = insert_user!()

      # 60 minutes
      insert_call_log!(creator,
        started_at: ~U[2026-01-01 09:00:00Z],
        ended_at: ~U[2026-01-01 10:00:00Z]
      )

      # 30 minutes
      insert_call_log!(creator,
        started_at: ~U[2026-01-02 09:00:00Z],
        ended_at: ~U[2026-01-02 09:30:00Z]
      )

      assert Affiliate.progress(creator).stream_minutes.current == 90
    end

    test "a session that hasn't ended yet doesn't count" do
      creator = insert_user!()

      insert_call_log!(creator, started_at: ~U[2026-01-01 09:00:00Z], ended_at: nil)

      assert Affiliate.progress(creator).stream_minutes.current == 0
    end

    test "sessions hosted by someone else don't count" do
      creator = insert_user!()
      someone_else = insert_user!()

      insert_call_log!(someone_else,
        started_at: ~U[2026-01-01 09:00:00Z],
        ended_at: ~U[2026-01-01 10:00:00Z]
      )

      assert Affiliate.progress(creator).stream_minutes.current == 0
    end
  end

  describe "progress/1 — metric shape" do
    test "percent is capped at 100 even when current exceeds target" do
      creator = insert_user!()
      for _ <- 1..75, do: insert_follow!(insert_user!(), creator)

      metric = Affiliate.progress(creator).followers
      assert metric.current == 75
      assert metric.percent == 100
    end

    test "all_met is only true once every axis is met" do
      creator = insert_user!()
      for _ <- 1..50, do: insert_follow!(insert_user!(), creator)

      # followers met, days_active and stream_minutes still at 0
      refute Affiliate.progress(creator).all_met
    end
  end

  describe "enable_subscriptions/1" do
    test "returns {:error, :gate_not_met} when thresholds aren't reached" do
      creator = insert_user!()
      assert Affiliate.enable_subscriptions(creator) == {:error, :gate_not_met}
    end

    test "flips subscriptions_enabled_at once all three axes are met" do
      creator = fully_qualified_creator!()

      assert {:ok, updated} = Affiliate.enable_subscriptions(creator)
      assert updated.subscriptions_enabled_at != nil
    end

    test "is idempotent -- calling again on an already-enabled user returns it unchanged" do
      creator = fully_qualified_creator!()
      {:ok, enabled} = Affiliate.enable_subscriptions(creator)

      assert {:ok, ^enabled} = Affiliate.enable_subscriptions(enabled)
    end
  end

  # --- fixtures ---

  defp insert_user!(attrs \\ %{}) do
    n = System.unique_integer([:positive])

    default = %{
      username: "affuser#{n}",
      email: "affuser#{n}@example.com",
      password: "supersecret123"
    }

    %User{}
    |> User.registration_changeset(Map.merge(default, attrs))
    |> Repo.insert!()
  end

  defp insert_follow!(follower, followed) do
    %UserFollow{}
    |> UserFollow.changeset(%{follower_id: follower.id, followed_id: followed.id})
    |> Repo.insert!()
  end

  defp insert_category! do
    n = System.unique_integer([:positive])

    %Category{}
    |> Category.changeset(%{name: "Category #{n}"})
    |> Repo.insert!()
  end

  defp insert_forum! do
    n = System.unique_integer([:positive])
    category = insert_category!()

    %Forum{}
    |> Forum.changeset(%{name: "Forum #{n}", category_id: category.id})
    |> Repo.insert!()
  end

  # Thread/Post use the plain timestamps() default (:naive_datetime), unlike
  # CallLog's explicitly-typed :utc_datetime started_at/ended_at -- accept a
  # DateTime at the call site (reads naturally) and convert here.
  defp insert_thread!(user, forum, opts) do
    n = System.unique_integer([:positive])
    inserted_at = Keyword.fetch!(opts, :inserted_at) |> DateTime.to_naive()
    is_hidden = Keyword.get(opts, :is_hidden, false)

    %Thread{
      title: "Thread #{n}",
      slug: "thread-#{n}",
      forum_id: forum.id,
      user_id: user.id,
      is_hidden: is_hidden,
      inserted_at: inserted_at,
      updated_at: inserted_at
    }
    |> Repo.insert!()
  end

  defp insert_post!(user, forum, opts) do
    thread = insert_thread!(user, forum, inserted_at: Keyword.fetch!(opts, :inserted_at))
    inserted_at = Keyword.fetch!(opts, :inserted_at) |> DateTime.to_naive()
    is_hidden = Keyword.get(opts, :is_hidden, false)

    %Post{
      body: "post body",
      thread_id: thread.id,
      user_id: user.id,
      is_hidden: is_hidden,
      inserted_at: inserted_at,
      updated_at: inserted_at
    }
    |> Repo.insert!()
  end

  defp insert_call_log!(host, opts) do
    %CallLog{
      host_user_id: host.id,
      started_at: Keyword.fetch!(opts, :started_at),
      ended_at: Keyword.get(opts, :ended_at)
    }
    |> Repo.insert!()
  end

  # A creator who clears all three affiliate-gate axes at once.
  defp fully_qualified_creator! do
    creator = insert_user!()
    forum = insert_forum!()

    for _ <- 1..50, do: insert_follow!(insert_user!(), creator)

    for day <- 1..7 do
      insert_post!(creator, forum,
        inserted_at: DateTime.new!(~D[2026-01-01], ~T[10:00:00]) |> DateTime.add(day - 1, :day)
      )
    end

    insert_call_log!(creator,
      started_at: ~U[2026-02-01 00:00:00Z],
      ended_at: DateTime.add(~U[2026-02-01 00:00:00Z], 500 * 60, :second)
    )

    creator
  end
end
