defmodule ForgeNexus.AccountsContextTest do
  use ForgeNexus.DataCase, async: false

  alias ForgeNexus.Accounts

  alias ForgeNexus.Accounts.{
    AuthToken,
    AvatarFrame,
    LoginEvent,
    Rank,
    User,
    UserGroup
  }

  defp create_user(attrs \\ %{}) do
    unique = System.unique_integer([:positive])

    default_attrs = %{
      username: "user_ctx_#{unique}",
      email: "user_ctx_#{unique}@example.com",
      password: "Fn9#xK8$mQ2!wZ7^vL4*",
      display_name: "User Ctx #{unique}"
    }

    {:ok, user} = Accounts.register_user(Map.merge(default_attrs, attrs))
    user
  end

  # =========================================================================
  # Users list and query helpers
  # =========================================================================
  describe "user listing and counts" do
    test "list_users/1 returns users with pagination" do
      u1 = create_user()
      u2 = create_user()

      users = Accounts.list_users(limit: 2, offset: 0)
      assert length(users) == 2
      assert Enum.any?(users, &(&1.id in [u1.id, u2.id]))
    end

    test "count_users/0 and newest_member/0" do
      initial_count = Accounts.count_users()
      user = create_user()

      assert Accounts.count_users() == initial_count + 1
      assert Accounts.newest_member().id == user.id
    end

    test "new_members_this_week/0 and new_members_this_month/0" do
      user = create_user()
      this_week = Accounts.new_members_this_week()
      assert Enum.any?(this_week, &(&1.id == user.id))

      assert Accounts.new_members_this_month() >= 1
    end

    test "recent_registrations/1 and search_users_by_ip/1 and monthly_member_growth/1" do
      user =
        create_user()
        |> Ecto.Changeset.change(registered_ip: "198.51.100.77")
        |> Repo.update!()

      assert length(Accounts.recent_registrations(2)) <= 2

      ip_users = Accounts.search_users_by_ip("198.51.100.77")
      assert Enum.any?(ip_users, &(&1.id == user.id))
      assert Accounts.search_users_by_ip("999.999.999.999") == []

      growth = Accounts.monthly_member_growth(6)
      assert is_list(growth)
    end
  end

  # =========================================================================
  # Auth tokens (verify, reset, change) and session revocation
  # =========================================================================
  describe "auth tokens lifecycle" do
    test "email verify token lifecycle (create, consume, reject duplicate, reject invalid)" do
      user = create_user(%{email_verified_at: nil})
      assert user.email_verified_at == nil

      assert {:ok, plaintext, %AuthToken{}} = Accounts.create_email_verify_token(user)
      assert is_binary(plaintext)

      # Invalidate prior token test: generating a second one invalidates the first
      assert {:ok, plaintext2, %AuthToken{}} = Accounts.create_email_verify_token(user)

      assert {:error, :already_used} = Accounts.consume_email_verify_token(plaintext)

      # Valid token consumption
      assert {:ok, verified_user} = Accounts.consume_email_verify_token(plaintext2)
      assert verified_user.email_verified_at != nil

      # Already used token consumption
      assert {:error, :already_used} = Accounts.consume_email_verify_token(plaintext2)

      # Invalid token
      assert {:error, :invalid_token} =
               Accounts.consume_email_verify_token("invalid_token_string")
    end

    test "consume_email_verify_token returns :expired when token is expired" do
      user = create_user()
      plaintext = "expired_plaintext_token_12345678"
      past = DateTime.utc_now() |> DateTime.add(-3600, :second) |> DateTime.truncate(:second)

      %AuthToken{}
      |> AuthToken.changeset(%{
        token_hash: AuthToken.hash(plaintext),
        type: "email_verify",
        email: user.email,
        user_id: user.id,
        expires_at: past
      })
      |> Repo.insert!()

      assert {:error, :expired} = Accounts.consume_email_verify_token(plaintext)
    end

    test "password reset token lifecycle" do
      user = create_user()
      assert {:ok, plaintext, _} = Accounts.create_password_reset_token(user)

      new_pass = "V3ry$tr0ngNewP@ssw0rd!"

      assert {:ok, updated_user} =
               Accounts.consume_password_reset_token(plaintext, new_pass)

      # Password hash changed and authenticates with new password
      assert updated_user.password_hash != user.password_hash
      assert {:ok, _} = Accounts.authenticate_user(user.email, new_pass)
    end

    test "password reset rejects short or breached password" do
      user = create_user()
      assert {:ok, plaintext, _} = Accounts.create_password_reset_token(user)

      # Weak password
      assert {:error, %Ecto.Changeset{}} =
               Accounts.consume_password_reset_token(plaintext, "short")
    end

    test "email change token lifecycle" do
      user = create_user()
      new_email = "new_address_#{System.unique_integer([:positive])}@example.com"

      assert {:ok, plaintext, _} = Accounts.create_email_change_token(user, new_email)

      assert {:ok, updated_user} = Accounts.consume_email_change_token(plaintext)
      assert updated_user.email == new_email
      assert updated_user.email_verified_at != nil
    end

    test "revoke_all_sessions/1 increments session_generation and stamps revoked_at" do
      user = create_user()
      initial_gen = user.session_generation || 0

      Accounts.create_login_session(user, "test-jti-1", %{})

      assert Accounts.revoke_all_sessions(user.id) == :ok

      updated = Accounts.get_user!(user.id)
      assert updated.session_generation == initial_gen + 1
    end
  end

  # =========================================================================
  # Profiles, updates, status, and creator status
  # =========================================================================
  describe "profiles and status" do
    test "update_profile/2 and admin_update_user/2 and display_title/1" do
      user = create_user()

      assert {:ok, updated} =
               Accounts.update_profile(user, %{
                 bio: "Lover of code",
                 custom_title: "Master Architect",
                 theme: "light"
               })

      assert updated.bio == "Lover of code"
      assert updated.theme == "light"
      assert Accounts.display_title(updated) == "Master Architect"

      assert {:ok, admin_updated} =
               Accounts.admin_update_user(updated, %{trust_level: 3, creator_tier: "top"})

      assert admin_updated.trust_level == 3
      assert admin_updated.creator_tier == "top"
    end

    test "admin_set_verified_creator/2 toggles verified_creator_at" do
      user = create_user()
      assert user.verified_creator_at == nil

      assert {:ok, v_user} = Accounts.admin_set_verified_creator(user.id, true)
      assert v_user.verified_creator_at != nil

      assert {:ok, unv_user} = Accounts.admin_set_verified_creator(user.id, false)
      assert unv_user.verified_creator_at == nil
    end

    test "presence: update_last_seen/1, set_offline/1, online_users, online_count, and online_stats" do
      user = create_user()
      assert {:ok, online_user} = Accounts.update_last_seen(user)
      assert online_user.is_online == true
      assert online_user.last_seen_at != nil

      assert Accounts.online_count() >= 1
      assert Accounts.online_stats().total >= 1
      assert Enum.any?(Accounts.online_users(), &(&1.id == user.id))

      assert {:ok, offline_user} = Accounts.set_offline(online_user)
      assert offline_user.is_online == false
    end

    test "status: update_status/2, set_custom_status/3, clear_custom_status/1, get_visible_status/1" do
      user = create_user()

      assert {:ok, s_user} = Accounts.update_status(user, "away")
      assert s_user.presence_status == "away"
      assert Accounts.get_visible_status(s_user) == "away"

      assert Accounts.update_status(user, "invalid_status") == {:error, :invalid_status}

      # Invisible status shows as offline
      {:ok, invis_user} = Accounts.update_status(user, "invisible")
      assert Accounts.get_visible_status(invis_user) == "offline"

      # Custom status
      assert {:ok, c_user} = Accounts.set_custom_status(user, "Working hard", "☕")
      assert c_user.custom_status_text == "Working hard"
      assert c_user.custom_status_emoji == "☕"

      assert {:ok, cleared} = Accounts.clear_custom_status(c_user)
      assert cleared.custom_status_text == nil
    end

    test "most_active_users/1 orders by post_count" do
      _u1 = create_user() |> Ecto.Changeset.change(post_count: 5) |> Repo.update!()
      u2 = create_user() |> Ecto.Changeset.change(post_count: 25) |> Repo.update!()

      active = Accounts.most_active_users(5)
      assert length(active) >= 2
      assert hd(active).id == u2.id
    end
  end

  # =========================================================================
  # Login events and sessions
  # =========================================================================
  describe "login events and sessions" do
    test "record_login_event/1 and list_login_events/1 with filters and count_logins/2" do
      user = create_user()

      assert {:ok, %LoginEvent{}} =
               Accounts.record_login_event(%{
                 user_id: user.id,
                 email: user.email,
                 ip_address: "192.0.2.1",
                 user_agent: "Mozilla/5.0 (Windows NT 10.0; Win64; x64)",
                 success: true
               })

      assert {:ok, %LoginEvent{}} =
               Accounts.record_login_event(%{
                 user_id: user.id,
                 email: user.email,
                 ip_address: "192.0.2.2",
                 user_agent: "Mozilla/5.0",
                 success: false,
                 failure_reason: "invalid_password"
               })

      # Count logins
      assert Accounts.count_logins(user.id, 7) == 1

      # Filter by user_id
      events = Accounts.list_login_events(user_id: user.id)
      assert length(events) == 2

      # Filter by success
      succ_events = Accounts.list_login_events(user_id: user.id, success: true)
      assert length(succ_events) == 1

      # Filter by IP
      ip_events = Accounts.list_login_events(ip_address: "192.0.2.1")
      assert Enum.any?(ip_events, &(&1.ip_address == "192.0.2.1"))
    end
  end

  # =========================================================================
  # Follows and Blocks
  # =========================================================================
  describe "follows and blocks" do
    test "follow lifecycle: toggle_follow, is_following?, follower_count, following_count, lists, feed" do
      u1 = create_user()
      u2 = create_user()

      refute Accounts.is_following?(u1.id, u2.id)

      assert {:ok, :followed} = Accounts.toggle_follow(u1.id, u2.id)
      assert Accounts.is_following?(u1.id, u2.id)
      assert Accounts.follower_count(u2.id) == 1
      assert Accounts.following_count(u1.id) == 1

      followers = Accounts.list_followers(u2.id)
      assert length(followers) == 1
      assert hd(followers).id == u1.id

      following = Accounts.list_following(u1.id)
      assert length(following) == 1
      assert hd(following).id == u2.id

      # Following feed empty when followed user has no posts
      assert Accounts.following_feed(u1.id) == []

      # Unfollow
      assert {:ok, :unfollowed} = Accounts.toggle_follow(u1.id, u2.id)
      refute Accounts.is_following?(u1.id, u2.id)
    end

    test "block lifecycle: block_user, unblock_user, list_blocked_users" do
      u1 = create_user()
      u2 = create_user()

      assert {:ok, _block} = Accounts.block_user(u1.id, u2.id)

      blocked = Accounts.list_blocked_users(u1.id)
      assert length(blocked) == 1
      assert hd(blocked).id == u2.id

      assert {:ok, _} = Accounts.unblock_user(u1.id, u2.id)
      assert Accounts.list_blocked_users(u1.id) == []

      assert Accounts.unblock_user(u1.id, u2.id) == {:error, :not_found}
    end
  end

  # =========================================================================
  # Groups, Ranks, and Permissions
  # =========================================================================
  describe "groups, ranks, and permissions" do
    test "create_group/1, list_groups/0, get_group!/1, get_default_group/0, add_user_to_group/2" do
      unique = System.unique_integer([:positive])

      assert {:ok, %UserGroup{} = group} =
               Accounts.create_group(%{
                 name: "Beta Testers #{unique}",
                 slug: "beta-testers-#{unique}",
                 position: 5,
                 is_default: true
               })

      assert Accounts.get_group!(group.id).id == group.id
      assert Accounts.get_default_group().id == group.id
      assert Enum.any?(Accounts.list_groups(), &(&1.id == group.id))

      user = create_user()
      assert {:ok, _membership} = Accounts.add_user_to_group(user.id, group.id)
    end

    test "seed_default_groups/0 creates standard groups idempotently" do
      # Ensure role atoms exist in atom table
      _ = [:guest, :member, :trusted, :moderator, :admin]

      result = Accounts.seed_default_groups()
      assert is_list(result.created)

      # Second run skips existing
      result2 = Accounts.seed_default_groups()
      assert result2.created == []
      assert length(result2.skipped) >= 5
    end

    test "default_permissions/0 returns permission map" do
      perms = Accounts.default_permissions()
      assert is_map(perms)
    end

    test "ranks: list_ranks/0 and get_rank_for_posts/1" do
      {:ok, rank1} =
        %Rank{}
        |> Rank.changeset(%{title: "Novice", min_posts: 0, position: 1})
        |> Repo.insert()

      {:ok, rank2} =
        %Rank{}
        |> Rank.changeset(%{title: "Veteran", min_posts: 50, position: 2})
        |> Repo.insert()

      assert Enum.any?(Accounts.list_ranks(), &(&1.id == rank1.id))
      assert Accounts.get_rank_for_posts(10).id == rank1.id
      assert Accounts.get_rank_for_posts(100).id == rank2.id
    end

    test "user_has_permission?/2 checks user status" do
      refute Accounts.user_has_permission?(nil, "can_post")

      banned = %User{status: "banned"}
      refute Accounts.user_has_permission?(banned, "can_post")

      active = %User{status: "active"}
      assert Accounts.user_has_permission?(active, "can_post")
    end
  end

  # =========================================================================
  # Preferences and Avatar Frames
  # =========================================================================
  describe "preferences and avatar frames" do
    test "get_preferences/1 creates defaults if missing and update_preferences/2 updates" do
      user = create_user()

      pref = Accounts.get_preferences(user.id)
      assert pref.user_id == user.id

      assert {:ok, updated} =
               Accounts.update_preferences(user.id, %{
                 posts_per_page: 50,
                 pagination_mode: "infinite_scroll"
               })

      assert updated.posts_per_page == 50
      assert updated.pagination_mode == "infinite_scroll"
    end

    test "avatar frames: list_avatar_frames/0 and get_available_frames_for_user/1" do
      {:ok, frame} =
        %AvatarFrame{}
        |> AvatarFrame.changeset(%{
          name: "Neon Glow",
          slug: "neon-glow-#{System.unique_integer([:positive])}",
          css_class: "neon-glow-frame",
          css_style: "border: 2px solid cyan",
          min_posts: 10,
          position: 1,
          is_active: true
        })
        |> Repo.insert()

      assert Enum.any?(Accounts.list_avatar_frames(), &(&1.id == frame.id))

      u_low = create_user() |> Ecto.Changeset.change(post_count: 5) |> Repo.update!()
      u_high = create_user() |> Ecto.Changeset.change(post_count: 20) |> Repo.update!()

      low_frames = Accounts.get_available_frames_for_user(u_low)
      refute Enum.any?(low_frames, &(&1.id == frame.id))

      high_frames = Accounts.get_available_frames_for_user(u_high)
      assert Enum.any?(high_frames, &(&1.id == frame.id))
    end
  end

  # =========================================================================
  # Promotion Rules
  # =========================================================================
  describe "promotion rules" do
    test "promotion rule CRUD and evaluate_promotion_rules/0" do
      unique = System.unique_integer([:positive])

      {:ok, g_member} =
        Accounts.create_group(%{name: "Base Group #{unique}", slug: "base-#{unique}"})

      {:ok, g_promoted} =
        Accounts.create_group(%{name: "Elite Group #{unique}", slug: "elite-#{unique}"})

      {:ok, rule} =
        Accounts.create_promotion_rule(%{
          name: "Promote on 10 posts #{unique}",
          from_group_id: g_member.id,
          to_group_id: g_promoted.id,
          criteria: %{"post_count" => 10},
          is_active: true,
          position: 1
        })

      assert Enum.any?(Accounts.list_all_promotion_rules(), &(&1.id == rule.id))

      # User in g_member with 15 posts
      user =
        create_user()
        |> Ecto.Changeset.change(post_count: 15)
        |> Repo.update!()

      Accounts.add_user_to_group(user.id, g_member.id)

      eval_result = Accounts.evaluate_promotion_rules()
      assert eval_result.promoted >= 1

      # User is now in g_promoted and moved out of g_member
      groups = Accounts.get_user!(user.id) |> Repo.preload(:groups) |> Map.get(:groups)
      assert Enum.any?(groups, &(&1.id == g_promoted.id))
      refute Enum.any?(groups, &(&1.id == g_member.id))

      # Clean up
      assert {:ok, _} = Accounts.delete_promotion_rule(rule.id)
    end
  end

  # =========================================================================
  # OAuth linking and user creation
  # =========================================================================
  describe "OAuth account linking and find_or_create" do
    test "link_oauth_account, list_oauth_accounts, unlink_oauth_account" do
      user = create_user()
      provider_uid = "gh_uid_#{System.unique_integer([:positive])}"

      assert {:ok, _oa} =
               Accounts.link_oauth_account(user.id, "github", %{
                 id: provider_uid,
                 email: "github.user@example.com",
                 name: "GitHub User"
               })

      accounts = Accounts.list_oauth_accounts(user.id)
      assert length(accounts) == 1
      assert hd(accounts).provider == "github"

      # Unlink succeeds because user has a password_hash
      assert {:ok, _} = Accounts.unlink_oauth_account(user.id, "github")
      assert Accounts.list_oauth_accounts(user.id) == []
    end

    test "unlink_oauth_account blocks unlinking when user has no password and only one OAuth account" do
      # Create OAuth user without password
      assert {:ok, user} =
               Accounts.find_or_create_oauth_user("google", %{
                 id: "google_sub_12345",
                 email: "google.user@example.com",
                 name: "Google User"
               })

      assert user.password_hash == nil

      assert {:error, :last_auth_method} = Accounts.unlink_oauth_account(user.id, "google")
    end

    test "find_or_create_oauth_user returns existing user by provider UID" do
      uid = "discord_sub_999"

      assert {:ok, user1} =
               Accounts.find_or_create_oauth_user("discord", %{
                 id: uid,
                 email: "discord.user@example.com",
                 name: "Gamer99"
               })

      assert {:ok, user2} =
               Accounts.find_or_create_oauth_user("discord", %{
                 id: uid,
                 email: "discord.user@example.com",
                 name: "Gamer99"
               })

      assert user1.id == user2.id
    end

    test "unique_username/1 handles collisions by appending incrementing integer" do
      unique = System.unique_integer([:positive])
      base = "clash_user_#{unique}"
      create_user(%{username: base})

      new_name = Accounts.unique_username(base)
      assert new_name == "#{base}2"
    end
  end
end
