defmodule ForgeNexus.AchievementsTest do
  use ForgeNexus.DataCase, async: true

  alias ForgeNexus.Achievements
  alias ForgeNexus.Achievements.Achievement
  alias ForgeNexus.Accounts
  alias ForgeNexus.Forums
  alias ForgeNexus.UserStats

  defp create_user(_suffix) do
    unique = System.unique_integer([:positive])

    {:ok, user} =
      Accounts.register_user(%{
        username: "ach_#{unique}",
        email: "ach_#{unique}@example.com",
        password: "ValidPassword123!@#"
      })

    user
  end

  defp achievement_attrs(attrs \\ %{}) do
    Enum.into(attrs, %{
      name: "Master Explorer #{System.unique_integer([:positive])}",
      slug: "master-explorer-#{System.unique_integer([:positive])}",
      description: "Explore everything",
      points: 50,
      is_active: true,
      sort_order: 10,
      criteria: %{"type" => "stat_threshold", "stat_key" => "posts_count", "threshold" => 5}
    })
  end

  describe "achievements CRUD and listing" do
    test "create_achievement/1 and get_achievement/1" do
      attrs = achievement_attrs(%{points: 25})
      assert {:ok, %Achievement{} = achievement} = Achievements.create_achievement(attrs)
      assert achievement.points == 25
      assert achievement.description == "Explore everything"

      assert %Achievement{id: id} = Achievements.get_achievement(achievement.id)
      assert id == achievement.id

      assert %Achievement{} = Achievements.get_achievement!(achievement.id)
      assert is_nil(Achievements.get_achievement(Ecto.UUID.generate()))
    end

    test "create_achievement/1 with invalid attributes" do
      assert {:error, changeset} = Achievements.create_achievement(%{name: nil})
      assert "can't be blank" in errors_on(changeset).name
    end

    test "define_achievement/1 alias inserts achievement" do
      attrs = achievement_attrs(%{name: "Defined Ach"})
      assert {:ok, %Achievement{} = ach} = Achievements.define_achievement(attrs)
      assert ach.name == "Defined Ach"
    end

    test "list_achievements/0 returns only active achievements sorted by sort_order" do
      {:ok, ach1} =
        Achievements.create_achievement(achievement_attrs(%{sort_order: 20, is_active: true}))

      {:ok, ach2} =
        Achievements.create_achievement(achievement_attrs(%{sort_order: 5, is_active: true}))

      {:ok, _inactive} =
        Achievements.create_achievement(achievement_attrs(%{sort_order: 1, is_active: false}))

      list = Achievements.list_achievements()
      ids = Enum.map(list, & &1.id)

      assert ach2.id in ids
      assert ach1.id in ids
      refute Enum.any?(list, fn a -> a.is_active == false end)

      pos1 = Enum.find_index(ids, &(&1 == ach1.id))
      pos2 = Enum.find_index(ids, &(&1 == ach2.id))
      assert pos2 < pos1
    end

    test "list_all_achievements/0 includes inactive achievements" do
      {:ok, inactive} = Achievements.create_achievement(achievement_attrs(%{is_active: false}))
      all = Achievements.list_all_achievements()
      assert Enum.any?(all, &(&1.id == inactive.id))
    end

    test "update_achievement/2 with struct and binary id" do
      {:ok, ach} = Achievements.create_achievement(achievement_attrs())

      assert {:ok, updated} = Achievements.update_achievement(ach, %{name: "Renamed Achievement"})
      assert updated.name == "Renamed Achievement"

      assert {:ok, updated2} =
               Achievements.update_achievement(ach.id, %{description: "Updated desc"})

      assert updated2.description == "Updated desc"

      assert {:error, :not_found} =
               Achievements.update_achievement(Ecto.UUID.generate(), %{name: "X"})
    end

    test "delete_achievement/1 with struct and binary id" do
      {:ok, ach1} = Achievements.create_achievement(achievement_attrs())
      {:ok, ach2} = Achievements.create_achievement(achievement_attrs())

      assert {:ok, %Achievement{}} = Achievements.delete_achievement(ach1)
      assert is_nil(Achievements.get_achievement(ach1.id))

      assert {:ok, %Achievement{}} = Achievements.delete_achievement(ach2.id)
      assert is_nil(Achievements.get_achievement(ach2.id))

      assert {:error, :not_found} = Achievements.delete_achievement(Ecto.UUID.generate())
    end
  end

  describe "unlock_achievement/2 and criteria evaluation" do
    test "evaluates criteria and unlocks achievement, awarding economy points" do
      user = create_user("eval_1")

      {:ok, ach} =
        Achievements.create_achievement(
          achievement_attrs(%{
            points: 50,
            criteria: %{"type" => "stat_threshold", "stat_key" => "posts_count", "threshold" => 3}
          })
        )

      refute Achievements.check_achievement(user.id, ach.id)

      UserStats.set_stat(user.id, "posts_count", 3.0)
      assert Achievements.check_achievement(user.id, ach.id)

      assert {:ok, %Achievement{}} = Achievements.unlock_achievement(user.id, ach.id)
      assert Achievements.unlock_count(ach.id) == 1

      # User points awarded via economy
      points = ForgeNexus.Economy.get_points(user.id)
      assert points == 50

      # Attempting duplicate unlock returns {:error, :already_unlocked}
      assert {:error, :already_unlocked} = Achievements.unlock_achievement(user.id, ach.id)
    end

    test "unlock_achievement/2 with 0 points skips economy award" do
      user = create_user("eval_0pts")
      {:ok, ach} = Achievements.create_achievement(achievement_attrs(%{points: 0}))

      assert {:ok, %Achievement{}} = Achievements.unlock_achievement(user.id, ach.id)
      assert ForgeNexus.Economy.get_points(user.id) == 0
    end

    test "evaluates count criteria and unknown criteria" do
      user = create_user("eval_count")

      {:ok, count_ach} =
        Achievements.create_achievement(
          achievement_attrs(%{
            criteria: %{"type" => "count", "stat_key" => "likes", "target" => 10}
          })
        )

      {:ok, unknown_ach} =
        Achievements.create_achievement(
          achievement_attrs(%{
            criteria: %{"type" => "unknown_rule"}
          })
        )

      refute Achievements.check_achievement(user.id, count_ach.id)
      refute Achievements.check_achievement(user.id, unknown_ach.id)

      UserStats.set_stat(user.id, "likes", 10.0)
      assert Achievements.check_achievement(user.id, count_ach.id)
    end

    test "list_user_achievements/1 and revoke_user_achievement/2" do
      user = create_user("list_user")
      {:ok, ach} = Achievements.create_achievement(achievement_attrs())

      assert Achievements.list_user_achievements(user.id) == []

      {:ok, _} = Achievements.unlock_achievement(user.id, ach.id)
      user_achs = Achievements.list_user_achievements(user.id)
      assert length(user_achs) == 1
      assert hd(user_achs).achievement.id == ach.id

      assert {:ok, _} = Achievements.revoke_user_achievement(user.id, ach.id)
      assert Achievements.list_user_achievements(user.id) == []

      assert {:error, :not_found} = Achievements.revoke_user_achievement(user.id, ach.id)
    end

    test "check_all_achievements/1 awards all eligible, skipping already unlocked" do
      user = create_user("check_all")

      {:ok, ach1} =
        Achievements.create_achievement(
          achievement_attrs(%{
            criteria: %{"type" => "stat_threshold", "stat_key" => "xp", "threshold" => 50}
          })
        )

      {:ok, ach2} =
        Achievements.create_achievement(
          achievement_attrs(%{
            criteria: %{"type" => "stat_threshold", "stat_key" => "xp", "threshold" => 100}
          })
        )

      UserStats.set_stat(user.id, "xp", 75.0)

      # ach1 unlocked, ach2 not yet
      unlocked = Achievements.check_all_achievements(user.id)
      assert length(unlocked) == 1
      assert hd(unlocked).id == ach1.id

      # Running again should skip already unlocked ach1
      assert Achievements.check_all_achievements(user.id) == []

      # Raising xp to 150 unlocks ach2
      UserStats.set_stat(user.id, "xp", 150.0)
      unlocked2 = Achievements.check_all_achievements(user.id)
      assert length(unlocked2) == 1
      assert hd(unlocked2).id == ach2.id
    end

    test "check_progress/2 returns detailed map or :not_found" do
      user = create_user("check_prog")

      {:ok, ach} =
        Achievements.create_achievement(
          achievement_attrs(%{
            criteria: %{"type" => "stat_threshold", "stat_key" => "threads", "threshold" => 1}
          })
        )

      assert {:error, :not_found} = Achievements.check_progress(user.id, Ecto.UUID.generate())

      assert {:ok, prog} = Achievements.check_progress(user.id, ach.id)
      assert prog.complete == false
      assert prog.percentage == 0.0

      UserStats.set_stat(user.id, "threads", 1.0)
      assert {:ok, prog2} = Achievements.check_progress(user.id, ach.id)
      assert prog2.complete == true
      assert prog2.percentage == 100.0
    end
  end

  describe "milestones API" do
    test "create_milestones/1 and check_milestones/2" do
      user = create_user("milestones_user")

      params = %{
        stat_type: "reputation",
        milestones: [10, 50, 100],
        reward_points_per: 20,
        community_id: "com_1"
      }

      assert {:ok, 3} = Achievements.create_milestones(params)

      UserStats.set_stat(user.id, "reputation", 55.0)
      unlocked = Achievements.check_milestones(user.id, "reputation")
      assert length(unlocked) == 2

      # Second check doesn't re-unlock
      assert Achievements.check_milestones(user.id, "reputation") == []
    end
  end

  describe "badge delegation helpers" do
    test "award_badge/2, revoke_badge/2, has_badge?/2, get_user_badges/1, set_badge_display/3" do
      user = create_user("badge_del")
      {:ok, badge} = Forums.create_badge(%{name: "Silver Star", category: "milestone"})

      refute Achievements.has_badge?(user.id, badge.id)

      assert {:ok, %{user_badge: _ub, was_new: true}} =
               Achievements.award_badge(user.id, badge.id)

      assert Achievements.has_badge?(user.id, badge.id)

      # Awarding again reflects was_new: false
      assert {:ok, %{was_new: false}} = Achievements.award_badge(user.id, badge.id)

      assert {:ok, user_badges} = Achievements.get_user_badges(user.id)
      assert length(user_badges) == 1

      # set_badge_display
      assert {:ok, updated_ub} = Achievements.set_badge_display(user.id, badge.id, 0)
      assert updated_ub.is_featured == true

      assert {:ok, updated_ub2} = Achievements.set_badge_display(user.id, badge.id, -1)
      assert updated_ub2.is_featured == false

      assert {:error, :not_found} =
               Achievements.set_badge_display(user.id, Ecto.UUID.generate(), 1)

      # revoke_badge
      assert {:ok, _} = Achievements.revoke_badge(user.id, badge.id)
      refute Achievements.has_badge?(user.id, badge.id)
    end
  end
end
