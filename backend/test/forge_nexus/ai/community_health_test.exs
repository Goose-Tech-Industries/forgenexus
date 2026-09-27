defmodule ForgeNexus.AI.CommunityHealthTest do
  use ForgeNexus.DataCase, async: false

  alias ForgeNexus.AI.CommunityHealth
  alias ForgeNexus.{Accounts, Communities, Forums, Repo}
  import Ecto.Query

  defp create_user(attrs \\ %{}) do
    uid = System.unique_integer([:positive])

    {:ok, user} =
      Accounts.register_user(
        Map.merge(
          %{
            username: "ch_user_#{uid}",
            email: "ch_user_#{uid}@example.com",
            password: "ValidPassword123!@#"
          },
          attrs
        )
      )

    user
  end

  defp create_community(owner) do
    uid = System.unique_integer([:positive])

    {:ok, comm} =
      Communities.create_community(%{
        name: "Health Comm #{uid}",
        slug: "health-comm-#{uid}",
        subdomain: "health#{uid}",
        owner_id: owner.id
      })

    comm
  end

  defp insert_health_score(community_id, score, calculated_at) do
    {:ok, id_bin} = Ecto.UUID.dump(Ecto.UUID.generate())
    {:ok, cid_bin} = Ecto.UUID.dump(community_id)

    Repo.insert_all("community_health_scores", [
      %{
        id: id_bin,
        community_id: cid_bin,
        score: score,
        trend: "stable",
        components: %{engagement: 50.0, moderation: 50.0, growth: 50.0, retention: 50.0},
        calculated_at: calculated_at,
        inserted_at: calculated_at,
        updated_at: calculated_at
      }
    ])
  end

  describe "calculate/1 and get_history/2" do
    test "calculates baseline health score for a new community" do
      owner = create_user()
      comm = create_community(owner)

      result = CommunityHealth.calculate(comm.id)

      assert is_map(result)
      assert is_float(result.score)
      assert result.trend == "new"
      assert is_map(result.components)
      assert Map.has_key?(result.components, :engagement)
      assert Map.has_key?(result.components, :moderation)
      assert Map.has_key?(result.components, :growth)
      assert Map.has_key?(result.components, :retention)

      # Verify history retrieval with default and custom days
      history_default = CommunityHealth.get_history(comm.id)
      assert length(history_default) == 1
      assert hd(history_default).score == result.score
      assert hd(history_default).trend == "new"

      history_7 = CommunityHealth.get_history(comm.id, 7)
      assert length(history_7) == 1
    end

    test "calculates all trend branches: up, down, stable" do
      owner = create_user()
      comm = create_community(owner)

      # 1. Previous score is very low (e.g. 5.0) -> current score will be higher by > 3 -> "up"
      insert_health_score(comm.id, 5.0, DateTime.utc_now() |> DateTime.add(10, :second))
      res_up = CommunityHealth.calculate(comm.id)
      assert res_up.trend == "up"

      # 2. Previous score is very high (e.g. 95.0) -> current score will be lower by > 3 -> "down"
      insert_health_score(comm.id, 95.0, DateTime.utc_now() |> DateTime.add(20, :second))
      res_down = CommunityHealth.calculate(comm.id)
      assert res_down.trend == "down"

      # 3. Previous score matches current score exactly -> "stable"
      insert_health_score(
        comm.id,
        res_down.score,
        DateTime.utc_now() |> DateTime.add(30, :second)
      )

      res_stable = CommunityHealth.calculate(comm.id)
      assert res_stable.trend == "stable"
    end

    test "exercises engagement, moderation, and member retention paths" do
      owner = create_user()
      comm = create_community(owner)
      {:ok, comm_bin} = Ecto.UUID.dump(comm.id)

      now = DateTime.utc_now() |> DateTime.truncate(:second)
      two_days_ago = DateTime.add(now, -2 * 86400, :second)

      {:ok, cat} =
        Forums.create_category(%{
          name: "Cat #{System.unique_integer()}",
          slug: "cat-#{System.unique_integer()}",
          position: 1
        })

      {:ok, forum} =
        Forums.create_forum(%{
          name: "Forum #{System.unique_integer()}",
          slug: "forum-#{System.unique_integer()}",
          category_id: cat.id
        })

      {:ok, thread} =
        Forums.create_thread(%{
          title: "Active Thread",
          body: "First post",
          forum_id: forum.id,
          user_id: owner.id
        })

      # Update thread and post with raw comm_bin
      from(t in "threads", where: t.id == type(^thread.id, :binary_id))
      |> Repo.update_all(set: [community_id: comm_bin, inserted_at: two_days_ago])

      from(p in "posts", where: p.thread_id == type(^thread.id, :binary_id))
      |> Repo.update_all(set: [community_id: comm_bin, inserted_at: two_days_ago])

      # Insert extra voice logs
      for _ <- 1..3 do
        {:ok, pid_bin} = Ecto.UUID.dump(Ecto.UUID.generate())

        Repo.insert_all("voice_call_logs", [
          %{
            id: pid_bin,
            community_id: comm_bin,
            started_at: two_days_ago,
            inserted_at: two_days_ago,
            updated_at: two_days_ago
          }
        ])
      end

      # Insert reports and bans
      for _ <- 1..2 do
        {:ok, rid_bin} = Ecto.UUID.dump(Ecto.UUID.generate())
        {:ok, uid_bin} = Ecto.UUID.dump(owner.id)

        Repo.insert_all("reports", [
          %{
            id: rid_bin,
            community_id: comm_bin,
            reportable_type: "post",
            reportable_id: rid_bin,
            reporter_id: uid_bin,
            reason: "spam",
            status: "pending",
            inserted_at: two_days_ago,
            updated_at: two_days_ago
          }
        ])

        {:ok, bid_bin} = Ecto.UUID.dump(Ecto.UUID.generate())

        Repo.insert_all("bans", [
          %{
            id: bid_bin,
            community_id: comm_bin,
            user_id: uid_bin,
            banned_by_id: uid_bin,
            reason: "rule break",
            inserted_at: two_days_ago,
            updated_at: two_days_ago
          }
        ])
      end

      # Associate active members
      u1 = create_user()

      from(u in "users", where: u.id == type(^u1.id, :binary_id))
      |> Repo.update_all(
        set: [community_id: comm_bin, last_seen_at: now, inserted_at: two_days_ago]
      )

      res = CommunityHealth.calculate(comm.id)
      assert is_float(res.score)
      assert res.components.engagement > 0.0
      assert res.components.retention > 0.0
    end

    test "handles growth_score when last_week > 0 (both positive and negative growth)" do
      owner = create_user()
      comm = create_community(owner)
      {:ok, comm_bin} = Ecto.UUID.dump(comm.id)

      now = DateTime.utc_now() |> DateTime.truncate(:second)
      ten_days_ago = DateTime.add(now, -10 * 86400, :second)
      three_days_ago = DateTime.add(now, -3 * 86400, :second)

      # 1. Negative growth: 5 users last week, 1 user this week
      for _ <- 1..5 do
        u = create_user()

        from(usr in "users", where: usr.id == type(^u.id, :binary_id))
        |> Repo.update_all(set: [community_id: comm_bin, inserted_at: ten_days_ago])
      end

      u_new = create_user()

      from(usr in "users", where: usr.id == type(^u_new.id, :binary_id))
      |> Repo.update_all(set: [community_id: comm_bin, inserted_at: three_days_ago])

      res_neg = CommunityHealth.calculate(comm.id)
      assert is_float(res_neg.components.growth)

      # 2. Positive growth: add 10 more users this week
      for _ <- 1..10 do
        u = create_user()

        from(usr in "users", where: usr.id == type(^u.id, :binary_id))
        |> Repo.update_all(set: [community_id: comm_bin, inserted_at: three_days_ago])
      end

      res_pos = CommunityHealth.calculate(comm.id)
      assert is_float(res_pos.components.growth)
      assert res_pos.components.growth > res_neg.components.growth
    end
  end
end
