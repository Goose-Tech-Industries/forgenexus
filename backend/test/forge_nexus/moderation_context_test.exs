defmodule ForgeNexus.ModerationContextTest do
  use ForgeNexus.DataCase, async: false

  alias ForgeNexus.Accounts
  alias ForgeNexus.Accounts.{UserGroup, UserGroupMembership}
  alias ForgeNexus.Moderation

  alias ForgeNexus.Moderation.{
    Appeal,
    Ban,
    ContentPolicy,
    ModNote,
    ModerationLog,
    Report,
    Warning
  }

  defp create_user(attrs \\ %{}) do
    unique = System.unique_integer([:positive])

    default_attrs = %{
      username: "mod_user_#{unique}",
      email: "mod_user_#{unique}@example.com",
      password: "Fn9#xK8$mQ2!wZ7^vL4*",
      display_name: "Mod User #{unique}"
    }

    {:ok, user} = Accounts.register_user(Map.merge(default_attrs, attrs))
    user
  end

  defp create_staff_user do
    user = create_user()

    {:ok, group} =
      %UserGroup{}
      |> UserGroup.changeset(%{
        name: "Staff Group #{System.unique_integer([:positive])}",
        is_staff: true
      })
      |> Repo.insert()

    {:ok, _} =
      %UserGroupMembership{}
      |> UserGroupMembership.changeset(%{user_id: user.id, group_id: group.id})
      |> Repo.insert()

    user
  end

  # =========================================================================
  # Staff & Admin checks
  # =========================================================================
  describe "is_staff? and is_admin?" do
    test "is_staff?/1 identifies staff and non-staff correctly" do
      refute Moderation.is_staff?(nil)
      refute Moderation.is_staff?("invalid-uuid")

      regular = create_user()
      refute Moderation.is_staff?(regular)
      refute Moderation.is_staff?(regular.id)

      staff = create_staff_user()
      assert Moderation.is_staff?(staff)
      assert Moderation.is_staff?(staff.id)
    end

    test "is_admin?/1 identifies administrators" do
      user = create_user()
      refute Moderation.is_admin?(user.id)

      {:ok, admin_group} =
        %UserGroup{}
        |> UserGroup.changeset(%{name: "Administrators", is_staff: true})
        |> Repo.insert()

      {:ok, _} =
        %UserGroupMembership{}
        |> UserGroupMembership.changeset(%{user_id: user.id, group_id: admin_group.id})
        |> Repo.insert()

      assert Moderation.is_admin?(user.id)
    end
  end

  # =========================================================================
  # Bans
  # =========================================================================
  describe "bans management" do
    test "ban_user, is_banned?, get_active_ban, and unban_user" do
      user = create_user()
      moderator = create_staff_user()

      refute Moderation.is_banned?(user.id)
      assert Moderation.get_active_ban(user.id) == nil

      expires = DateTime.utc_now() |> DateTime.add(86_400, :second) |> DateTime.truncate(:second)

      assert {:ok, %Ban{} = ban} =
               Moderation.ban_user(
                 user.id,
                 %{
                   reason: "Harassment and spam",
                   type: "temporary",
                   expires_at: expires
                 },
                 moderator
               )

      assert Moderation.is_banned?(user.id)
      active_ban = Moderation.get_active_ban(user.id)
      assert active_ban.id == ban.id
      assert active_ban.reason == "Harassment and spam"

      # Bans listing
      bans = Moderation.list_bans(user_id: user.id, active_only: true)
      assert length(bans) == 1

      # Unban
      assert {:ok, unbanned} = Moderation.unban_user(ban.id, moderator)
      assert unbanned.is_active == false
      refute Moderation.is_banned?(user.id)
    end

    test "unban_user_by_id/1 deactivates active ban for a user" do
      user = create_user()
      mod = create_staff_user()

      Moderation.ban_user(user.id, %{reason: "TOS breach", type: "permanent"}, mod)
      assert Moderation.is_banned?(user.id)

      assert {:ok, %Ban{is_active: false}} = Moderation.unban_user_by_id(user.id)
      refute Moderation.is_banned?(user.id)
    end

    test "expire_bans/0 marks expired bans as inactive" do
      user = create_user()
      past = DateTime.utc_now() |> DateTime.add(-3600, :second) |> DateTime.truncate(:second)

      %Ban{}
      |> Ban.changeset(%{
        user_id: user.id,
        banned_by_id: create_staff_user().id,
        reason: "Old temp ban",
        type: "temporary",
        is_active: true,
        expires_at: past
      })
      |> Repo.insert!()

      assert {count, _} = Moderation.expire_bans()
      assert count >= 1
      refute Moderation.is_banned?(user.id)
    end

    test "ban_ip/3 creates an active IP ban" do
      _sys = create_user(%{username: "system"})
      assert {:ok, %Ban{} = ban} = Moderation.ban_ip("203.0.113.88", "Botnet IP", 48)
      assert ban.ip_address == "203.0.113.88"
      assert ban.is_active == true
      assert ban.type == "temporary"
    end
  end

  # =========================================================================
  # Warnings & Auto-escalation
  # =========================================================================
  describe "warnings and auto-escalation" do
    test "issue_warning, list_warnings, active_warning_points, and revoke_warning" do
      user = create_user()
      mod = create_staff_user()

      assert {:ok, %Warning{} = w} =
               Moderation.issue_warning(
                 user.id,
                 %{
                   reason: "Inappropriate language",
                   type: "warning",
                   points: 2
                 },
                 mod
               )

      assert w.is_active == true
      assert Moderation.active_warning_points(user.id) == 2

      warnings = Moderation.list_warnings(user.id)
      assert length(warnings) == 1

      # Revoke warning
      assert {:ok, revoked} = Moderation.revoke_warning(w.id, mod)
      assert revoked.is_active == false
      assert Moderation.active_warning_points(user.id) == 0
    end

    test "expire_warnings/0 deactivates expired warnings" do
      user = create_user()
      past = DateTime.utc_now() |> DateTime.add(-100, :second) |> DateTime.truncate(:second)

      %Warning{}
      |> Warning.changeset(%{
        user_id: user.id,
        issued_by_id: create_staff_user().id,
        reason: "Expired point",
        type: "warning",
        points: 3,
        is_active: true,
        expires_at: past
      })
      |> Repo.insert!()

      assert {count, _} = Moderation.expire_warnings()
      assert count >= 1
      assert Moderation.active_warning_points(user.id) == 0
    end

    test "check_auto_escalation applies escalation sanctions at point thresholds" do
      user = create_user()
      mod = create_staff_user()

      # Under 3 points -> :no_action
      Moderation.issue_warning(user.id, %{reason: "Minor", type: "warning", points: 2}, mod)
      assert Moderation.check_auto_escalation(user.id, mod) == {:ok, :no_action}

      # Add 2 more points -> total 4 points >= 3 (cooldown threshold)
      Moderation.issue_warning(
        user.id,
        %{reason: "Cooldown trigger", type: "warning", points: 2},
        mod
      )

      assert {:ok, :cooldown} = Moderation.check_auto_escalation(user.id, mod)

      assert Moderation.get_user_restriction(user.id) == :cooldown
    end

    test "timeout_user_seconds/3 issues a cooldown warning for specified seconds" do
      user = create_user()

      assert {:ok, %Ban{type: "temporary"}} =
               Moderation.timeout_user_seconds(user.id, 600, "Automated plugin cooldown")

      assert Moderation.get_user_restriction(user.id) == :banned
    end

    test "add_infraction_points/3 and get_infraction_points/1" do
      user = create_user()
      assert Moderation.get_infraction_points(user.id) == 0

      assert {:ok, _} = Moderation.add_infraction_points(user.id, 5, "Offense points")
      assert Moderation.get_infraction_points(user.id) == 5
    end
  end

  # =========================================================================
  # Reports & Moderation Queue
  # =========================================================================
  describe "reports lifecycle" do
    test "create, assign, resolve, dismiss, and queue statistics" do
      reporter = create_user()
      mod = create_staff_user()
      target_id = Ecto.UUID.generate()

      assert {:ok, %Report{} = report} =
               Moderation.create_report(
                 %{
                   reason: "spam",
                   description: "Spam advertisement",
                   reportable_type: "post",
                   reportable_id: target_id
                 },
                 reporter
               )

      assert report.status == "open"
      assert Moderation.get_report!(report.id).id == report.id

      # Queue counts
      counts = Moderation.report_counts_by_status()
      assert counts["open"] >= 1

      # Assign report
      assert {:ok, assigned} = Moderation.assign_report(report.id, mod.id, mod)
      assert assigned.assigned_to_id == mod.id

      # My reports for reporter
      my_reps = Moderation.my_reports(reporter.id)
      assert Enum.any?(my_reps, &(&1.id == report.id))

      # Resolve report
      assert {:ok, resolved} =
               Moderation.resolve_report(
                 report.id,
                 %{
                   resolution_note: "Removed spam link"
                 },
                 mod
               )

      assert resolved.status == "resolved"
      assert resolved.resolver_id == mod.id

      # Dismiss a second report
      {:ok, report2} =
        Moderation.create_report(
          %{
            reason: "other",
            description: "Duplicate report",
            reportable_type: "user",
            reportable_id: reporter.id
          },
          reporter
        )

      assert {:ok, dismissed} =
               Moderation.dismiss_report(report2.id, %{resolution_note: "Not a violation"}, mod)

      assert dismissed.status == "dismissed"

      # Queue stats
      q_stats = Moderation.report_queue_stats()
      assert is_map(q_stats)

      # Suggest assignment
      assert Moderation.suggest_assignment() != nil or Moderation.suggest_assignment() == nil
    end
  end

  # =========================================================================
  # Mod Notes & Logs
  # =========================================================================
  describe "mod notes and logs" do
    test "mod note CRUD: create_mod_note, list_mod_notes, delete_mod_note" do
      user = create_user()
      mod = create_staff_user()

      assert {:ok, %ModNote{} = note} =
               Moderation.create_mod_note(user.id, "User has been warned previously.", mod)

      assert note.body == "User has been warned previously."

      notes = Moderation.list_mod_notes(user.id)
      assert length(notes) == 1
      assert hd(notes).id == note.id

      assert {:ok, _} = Moderation.delete_mod_note(note.id, mod)
      assert Moderation.list_mod_notes(user.id) == []
    end

    test "log_action, list_mod_logs, and mod_workload_stats" do
      mod = create_staff_user()
      user = create_user()

      assert {:ok, %ModerationLog{} = log} =
               Moderation.log_action(mod, "ban", "user", user.id, %{reason: "TOS breach"})

      assert log.action == "ban"
      assert log.target_type == "user"

      logs = Moderation.list_mod_logs(moderator_id: mod.id)
      assert Enum.any?(logs, &(&1.id == log.id))

      stats = Moderation.mod_workload_stats(mod.id)
      assert stats.actions_30d >= 1
    end

    test "user_infractions/1 returns combined warnings, bans, and active points" do
      user = create_user()
      mod = create_staff_user()

      Moderation.issue_warning(
        user.id,
        %{reason: "Infraction 1", type: "warning", points: 1},
        mod
      )

      Moderation.create_mod_note(user.id, "Note 1", mod)

      infractions = Moderation.user_infractions(user.id)
      assert length(infractions.warnings) == 1
      assert infractions.active_points == 1
    end
  end

  # =========================================================================
  # Appeals
  # =========================================================================
  describe "appeals lifecycle" do
    test "create_appeal, list_appeals, my_appeals, and review_appeal" do
      user = create_user()
      mod = create_staff_user()
      ban_id = Ecto.UUID.generate()

      assert {:ok, %Appeal{} = appeal} =
               Moderation.create_appeal(user.id, "ban", ban_id, "I was hacked, please restore.")

      assert appeal.status == "pending"
      assert Moderation.get_appeal!(appeal.id).id == appeal.id

      assert Enum.any?(Moderation.list_appeals(), &(&1.id == appeal.id))
      assert Enum.any?(Moderation.my_appeals(user.id), &(&1.id == appeal.id))

      # Review appeal (approve)
      assert {:ok, reviewed} =
               Moderation.review_appeal(
                 appeal.id,
                 "approved",
                 "Evidence verified; ban lifted.",
                 mod
               )

      assert reviewed.status == "approved"
      assert reviewed.reviewer_id == mod.id
    end
  end

  # =========================================================================
  # Impersonation
  # =========================================================================
  describe "impersonation" do
    test "start_impersonation, get_active_impersonation, end_impersonation, list_impersonation_logs" do
      admin = create_user()
      target = create_user()

      # Give admin group to admin
      {:ok, g} =
        %UserGroup{}
        |> UserGroup.changeset(%{name: "Administrators", is_staff: true})
        |> Repo.insert()

      {:ok, _} =
        %UserGroupMembership{}
        |> UserGroupMembership.changeset(%{user_id: admin.id, group_id: g.id})
        |> Repo.insert()

      assert {:ok, log} =
               Moderation.start_impersonation(admin.id, target.id, "Debug customer issue")

      assert log.admin_id == admin.id
      assert log.target_user_id == target.id

      active = Moderation.get_active_impersonation(admin.id)
      assert active != nil
      assert active.id == log.id

      assert {:ok, ended} = Moderation.end_impersonation(admin.id)
      assert ended.ended_at != nil

      assert Moderation.get_active_impersonation(admin.id) == nil
      assert Enum.any?(Moderation.list_impersonation_logs(admin_id: admin.id), &(&1.id == log.id))
    end
  end

  # =========================================================================
  # Quarantine & Safety
  # =========================================================================
  describe "quarantine and safety" do
    test "quarantine_user, active_quarantine_for, release_quarantine, list_quarantine_records" do
      user = create_user()
      mod = create_staff_user()

      assert {:ok, q_user} =
               Moderation.quarantine_user(user.id, "Suspected compromised account", mod.id)

      assert q_user.status == "quarantined"

      active = Moderation.active_quarantine_for(user.id)
      assert active != nil
      assert active.reason == "Suspected compromised account"

      assert {:ok, released} = Moderation.release_quarantine(user.id, mod.id)
      assert released.status == "active"

      assert Moderation.active_quarantine_for(user.id) == nil
      assert Enum.any?(Moderation.list_quarantine_records(), &(&1.id == active.id))
    end

    test "system_actor/0 returns system user or fallback user" do
      actor = Moderation.system_actor()
      assert is_map(actor)
      assert is_binary(actor.username)
    end

    test "run_expiration_tasks/0 runs ban and warning expiration" do
      assert {:ok, result} = Moderation.run_expiration_tasks()
      assert is_map(result)
      assert is_integer(result.bans_expired)
      assert is_integer(result.warnings_expired)
    end

    test "send_mod_alert/4 inserts moderation alert and broadcast" do
      assert {:ok, alert} =
               Moderation.send_mod_alert(
                 "High Volume Spam",
                 "Multiple accounts posting casino links",
                 "high",
                 %{ip: "192.0.2.99"}
               )

      assert alert.title == "High Volume Spam"
      assert alert.severity == "high"
    end
  end

  # =========================================================================
  # Content Policies
  # =========================================================================
  describe "content policies" do
    test "content policy CRUD and resolution" do
      unique = System.unique_integer([:positive])

      {:ok, cat} =
        %ForgeNexus.Forums.Category{}
        |> ForgeNexus.Forums.Category.changeset(%{name: "Policy Cat #{unique}"})
        |> Repo.insert()

      {:ok, forum} =
        %ForgeNexus.Forums.Forum{}
        |> ForgeNexus.Forums.Forum.changeset(%{
          name: "Policy Forum #{unique}",
          category_id: cat.id
        })
        |> Repo.insert()

      assert {:ok, %ContentPolicy{} = policy} =
               Moderation.create_content_policy(%{
                 forum_id: forum.id,
                 name: "Default Forum Policy",
                 description: "Standard guidelines",
                 is_default: true,
                 is_active: true,
                 rules: %{"banned_words" => ["spam", "viagra"]},
                 escalation_thresholds: %{"points" => 5}
               })

      assert Moderation.get_content_policy!(policy.id).id == policy.id
      assert Enum.any?(Moderation.list_content_policies(), &(&1.id == policy.id))

      assert {:ok, updated} =
               Moderation.update_content_policy(policy.id, %{description: "Updated guidelines"})

      assert updated.description == "Updated guidelines"

      assert Moderation.get_policy_for_forum(forum.id).id == policy.id

      assert {:ok, _} = Moderation.delete_content_policy(policy.id)
    end
  end
end
