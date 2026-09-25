defmodule ForgeNexus.Achievements.AchievementsSchemasTest do
  use ForgeNexus.DataCase, async: true

  alias ForgeNexus.Achievements.{Achievement, UserAchievement}

  describe "Achievement" do
    test "valid changeset" do
      cs =
        Achievement.changeset(%Achievement{}, %{
          name: "First Post",
          slug: "first-post",
          description: "Made your very first post",
          criteria: %{"type" => "post_count", "threshold" => 1},
          points: 10
        })

      assert cs.valid?
      assert get_field(cs, :name) == "First Post"

      req_cs = Achievement.changeset(%Achievement{}, %{criteria: nil})
      refute req_cs.valid?
      assert "can't be blank" in errors_on(req_cs).name
      assert "can't be blank" in errors_on(req_cs).slug
      assert "can't be blank" in errors_on(req_cs).criteria
    end
  end

  describe "UserAchievement" do
    @uid Ecto.UUID.generate()
    @aid Ecto.UUID.generate()

    test "valid changeset" do
      now = ~U[2026-03-01 12:00:00Z]

      cs =
        UserAchievement.changeset(%UserAchievement{}, %{
          user_id: @uid,
          achievement_id: @aid,
          unlocked_at: now
        })

      assert cs.valid?
      assert get_field(cs, :unlocked_at) == now

      req_cs = UserAchievement.changeset(%UserAchievement{}, %{})
      refute req_cs.valid?
      assert "can't be blank" in errors_on(req_cs).user_id
      assert "can't be blank" in errors_on(req_cs).achievement_id
      assert "can't be blank" in errors_on(req_cs).unlocked_at
    end
  end
end
