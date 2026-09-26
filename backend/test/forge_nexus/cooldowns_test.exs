defmodule ForgeNexus.CooldownsTest do
  use ForgeNexus.DataCase, async: true

  alias ForgeNexus.Accounts
  alias ForgeNexus.Cooldowns
  alias ForgeNexus.Cooldowns.UserCooldown

  defp create_user do
    unique = System.unique_integer([:positive])

    {:ok, user} =
      Accounts.register_user(%{
        username: "cd_user_#{unique}",
        email: "cd_user_#{unique}@example.com",
        password: "Fn9#xK8$mQ2!wZ7^vL4*",
        display_name: "CD User #{unique}"
      })

    user
  end

  describe "UserCooldown changeset" do
    test "validates required fields" do
      changeset = UserCooldown.changeset(%UserCooldown{}, %{})
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).user_id
      assert "can't be blank" in errors_on(changeset).action_key
      assert "can't be blank" in errors_on(changeset).expires_at
    end

    test "produces a valid changeset with proper attributes" do
      user = create_user()
      expires = DateTime.utc_now() |> DateTime.add(60, :second) |> DateTime.truncate(:second)

      changeset =
        UserCooldown.changeset(%UserCooldown{}, %{
          user_id: user.id,
          action_key: "create_thread",
          expires_at: expires
        })

      assert changeset.valid?
      assert get_change(changeset, :action_key) == "create_thread"
    end
  end

  describe "Cooldowns context operations" do
    test "check_cooldown/2 returns {:ok, :ready} when no cooldown exists" do
      user = create_user()
      assert Cooldowns.check_cooldown(user.id, "post_shout") == {:ok, :ready}
    end

    test "set_cooldown/3 sets new cooldown and check_cooldown/2 returns {:error, diff}" do
      user = create_user()

      assert {:ok, %UserCooldown{} = cd} = Cooldowns.set_cooldown(user.id, "post_shout", 60)
      assert cd.action_key == "post_shout"
      assert cd.user_id == user.id

      assert {:error, remaining} = Cooldowns.check_cooldown(user.id, "post_shout")
      assert remaining >= 55 and remaining <= 60
    end

    test "set_cooldown/3 updates existing cooldown expiration" do
      user = create_user()

      {:ok, cd1} = Cooldowns.set_cooldown(user.id, "claim_daily", 30)
      {:ok, cd2} = Cooldowns.set_cooldown(user.id, "claim_daily", 120)

      assert cd1.id == cd2.id
      assert DateTime.compare(cd2.expires_at, cd1.expires_at) == :gt
    end

    test "check_cooldown/2 returns {:ok, :ready} when cooldown has expired" do
      user = create_user()
      past = DateTime.utc_now() |> DateTime.add(-10, :second) |> DateTime.truncate(:second)

      {:ok, _cd} =
        %UserCooldown{}
        |> UserCooldown.changeset(%{
          user_id: user.id,
          action_key: "expired_action",
          expires_at: past
        })
        |> Repo.insert()

      assert Cooldowns.check_cooldown(user.id, "expired_action") == {:ok, :ready}
    end

    test "clear_cooldown/2 deletes cooldown record" do
      user = create_user()
      Cooldowns.set_cooldown(user.id, "post_comment", 100)

      assert Cooldowns.clear_cooldown(user.id, "post_comment") == :ok
      assert Cooldowns.check_cooldown(user.id, "post_comment") == {:ok, :ready}
    end

    test "get_remaining/2 returns positive seconds when active, 0 when expired or absent" do
      user = create_user()

      assert Cooldowns.get_remaining(user.id, "no_cooldown") == 0

      Cooldowns.set_cooldown(user.id, "active_cd", 50)
      remaining = Cooldowns.get_remaining(user.id, "active_cd")
      assert remaining >= 45 and remaining <= 50

      # Manually set expired record
      past = DateTime.utc_now() |> DateTime.add(-30, :second) |> DateTime.truncate(:second)

      %UserCooldown{}
      |> UserCooldown.changeset(%{
        user_id: user.id,
        action_key: "past_cd",
        expires_at: past
      })
      |> Repo.insert!()

      assert Cooldowns.get_remaining(user.id, "past_cd") == 0
    end

    test "cleanup_expired/0 removes past cooldowns while preserving active ones" do
      user = create_user()
      past = DateTime.utc_now() |> DateTime.add(-100, :second) |> DateTime.truncate(:second)

      %UserCooldown{}
      |> UserCooldown.changeset(%{
        user_id: user.id,
        action_key: "old_action_1",
        expires_at: past
      })
      |> Repo.insert!()

      %UserCooldown{}
      |> UserCooldown.changeset(%{
        user_id: user.id,
        action_key: "old_action_2",
        expires_at: past
      })
      |> Repo.insert!()

      Cooldowns.set_cooldown(user.id, "still_active", 500)

      assert {:ok, count} = Cooldowns.cleanup_expired()
      assert count >= 2

      # Active is preserved
      assert Cooldowns.get_remaining(user.id, "still_active") > 0
      # Past is gone
      assert Cooldowns.get_remaining(user.id, "old_action_1") == 0
    end
  end
end
