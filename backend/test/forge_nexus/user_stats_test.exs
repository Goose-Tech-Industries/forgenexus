defmodule ForgeNexus.UserStatsTest do
  use ForgeNexus.DataCase, async: true

  alias ForgeNexus.UserStats
  alias ForgeNexus.UserStats.UserStat
  alias ForgeNexus.Accounts

  defp create_user do
    unique = System.unique_integer([:positive])

    {:ok, user} =
      Accounts.register_user(%{
        username: "stat_u_#{unique}",
        email: "stat_u_#{unique}@example.com",
        password: "ValidPassword123!@#"
      })

    user
  end

  describe "get_stat/2 and set_stat/3" do
    test "returns 0.0 for non-existent stat" do
      user = create_user()
      assert UserStats.get_stat(user.id, "nonexistent") == 0.0
    end

    test "inserts new stat and updates existing" do
      user = create_user()
      assert {:ok, %UserStat{}} = UserStats.set_stat(user.id, "coins", 150.0)
      assert UserStats.get_stat(user.id, "coins") == 150.0

      assert {:ok, %UserStat{}} = UserStats.set_stat(user.id, "coins", 200.0)
      assert UserStats.get_stat(user.id, "coins") == 200.0
    end

    test "respects min_value and max_value clamping on update" do
      user = create_user()

      # Insert with bounds
      %UserStat{}
      |> UserStat.changeset(%{
        user_id: user.id,
        stat_key: "health",
        value: 50.0,
        min_value: 0.0,
        max_value: 100.0
      })
      |> ForgeNexus.Repo.insert!()

      # Clamps above max
      UserStats.set_stat(user.id, "health", 150.0)
      assert UserStats.get_stat(user.id, "health") == 100.0

      # Clamps below min
      UserStats.set_stat(user.id, "health", -20.0)
      assert UserStats.get_stat(user.id, "health") == 0.0

      # Within bounds
      UserStats.set_stat(user.id, "health", 75.0)
      assert UserStats.get_stat(user.id, "health") == 75.0
    end
  end

  describe "modify_stat/3" do
    test "modifies existing stat or initializes from 0" do
      user = create_user()

      assert {:ok, _} = UserStats.modify_stat(user.id, "reputation", 10.0)
      assert UserStats.get_stat(user.id, "reputation") == 10.0

      assert {:ok, _} = UserStats.modify_stat(user.id, "reputation", -4.0)
      assert UserStats.get_stat(user.id, "reputation") == 6.0
    end
  end

  describe "get_all_stats/1" do
    test "returns map of all user stats" do
      user = create_user()
      UserStats.set_stat(user.id, "posts", 5.0)
      UserStats.set_stat(user.id, "threads", 2.0)

      stats = UserStats.get_all_stats(user.id)
      assert stats["posts"] == 5.0
      assert stats["threads"] == 2.0
    end
  end

  describe "get_level/1 and check_stat/3" do
    test "calculates level for 0 xp or negative xp" do
      user = create_user()
      assert UserStats.get_level(user.id) == 1

      UserStats.set_stat(user.id, "xp", -10.0)
      assert UserStats.get_level(user.id) == 1
    end

    test "calculates level for positive xp" do
      user = create_user()
      UserStats.set_stat(user.id, "xp", 250.0)
      level = UserStats.get_level(user.id)
      assert is_integer(level)
      assert level >= 1
    end

    test "check_stat/3 checks threshold" do
      user = create_user()
      UserStats.set_stat(user.id, "score", 45.0)

      assert UserStats.check_stat(user.id, "score", 40.0)
      assert UserStats.check_stat(user.id, "score", 45.0)
      refute UserStats.check_stat(user.id, "score", 50.0)
    end
  end
end
