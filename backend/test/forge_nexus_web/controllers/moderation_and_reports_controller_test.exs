defmodule ForgeNexusWeb.ModerationAndReportsControllerTest do
  use ForgeNexusWeb.ConnCase, async: false

  alias ForgeNexus.Accounts
  alias ForgeNexus.Forums
  alias ForgeNexus.Moderation
  alias ForgeNexus.Guardian

  defp fresh_conn(conn) do
    b3 = rem(System.unique_integer([:positive]), 250) + 1
    b4 = rem(System.unique_integer([:positive]), 250) + 1
    %{conn | remote_ip: {10, 0, b3, b4}}
  end

  defp create_user(attrs \\ %{}) do
    unique = System.unique_integer([:positive])

    default_attrs = %{
      username: "user_#{unique}",
      email: "user_#{unique}@example.com",
      password: "Fn9#xK8$mQ2!wZ7^vL4*",
      display_name: "Test User #{unique}"
    }

    {:ok, user} = Accounts.register_user(Map.merge(default_attrs, attrs))

    now = DateTime.utc_now() |> DateTime.truncate(:second)

    {:ok, verified} =
      user |> Ecto.Changeset.change(email_verified_at: now) |> ForgeNexus.Repo.update()

    verified
  end

  defp create_staff_user(attrs \\ %{}) do
    user = create_user(attrs)
    unique = System.unique_integer([:positive])

    {:ok, group} =
      Accounts.create_group(%{
        name: "Staff Group #{unique}",
        slug: "staff-group-#{unique}",
        is_staff: true,
        color: "#FF0000"
      })

    {:ok, _membership} = Accounts.add_user_to_group(user.id, group.id)
    user
  end

  defp auth_conn(conn, user) do
    {:ok, token, _claims} = Guardian.encode_and_sign(user)

    conn
    |> fresh_conn()
    |> put_req_header("authorization", "Bearer #{token}")
    |> put_req_cookie("fn_token", token)
  end

  defp create_forum_and_thread(user) do
    unique = System.unique_integer([:positive])

    {:ok, cat} =
      Forums.create_category(%{
        name: "Mod Cat #{unique}",
        slug: "mod-cat-#{unique}",
        position: 1
      })

    {:ok, forum} =
      Forums.create_forum(%{
        name: "Mod Forum #{unique}",
        slug: "mod-forum-#{unique}",
        category_id: cat.id,
        position: 1
      })

    {:ok, thread} =
      Forums.create_thread(%{
        "title" => "Mod Thread #{unique}",
        "body" => "Mod Thread Body #{unique}",
        "forum_id" => forum.id,
        "user_id" => user.id
      })

    post = Forums.get_first_post(thread.id)
    {forum, thread, post}
  end

  # =========================================================================
  # ReportController Tests
  # =========================================================================
  describe "ReportController" do
    test "POST /api/reports creates a report", %{conn: conn} do
      user = create_user()
      {_forum, _thread, post} = create_forum_and_thread(user)

      report_params = %{
        "report" => %{
          "reason" => "spam",
          "description" => "Posting commercial links repeatedly",
          "reportable_type" => "post",
          "reportable_id" => post.id
        }
      }

      conn =
        conn
        |> auth_conn(user)
        |> post(~p"/api/reports", report_params)

      response = json_response(conn, 201)
      assert response["report"]["reason"] == "spam"
      assert response["report"]["status"] == "open"
    end

    test "POST /api/reports requires authentication", %{conn: conn} do
      conn = post(fresh_conn(conn), ~p"/api/reports", %{"report" => %{}})
      assert response(conn, 401)
    end

    test "POST /api/reports returns 422 on invalid reason", %{conn: conn} do
      user = create_user()

      report_params = %{
        "report" => %{
          "reason" => "invalid_reason_string",
          "description" => "Bad",
          "reportable_type" => "post",
          "reportable_id" => Ecto.UUID.generate()
        }
      }

      conn =
        conn
        |> auth_conn(user)
        |> post(~p"/api/reports", report_params)

      assert json_response(conn, 422)["error"] != nil
    end
  end

  # =========================================================================
  # AppealController Tests
  # =========================================================================
  describe "AppealController" do
    test "POST /api/appeals, GET /api/appeals/mine, and GET /api/my/infractions", %{conn: conn} do
      user = create_user()
      staff = create_staff_user()

      # Staff issues a warning to user
      {:ok, warning} =
        Moderation.issue_warning(
          user.id,
          %{type: "warning", reason: "Disrespectful language", points: 2},
          staff
        )

      # User submits appeal
      appeal_params = %{
        "appeal" => %{
          "type" => "warning",
          "target_id" => warning.id,
          "reason" => "I apologize and it will not happen again."
        }
      }

      conn_appeal =
        conn
        |> auth_conn(user)
        |> post(~p"/api/appeals", appeal_params)

      appeal_resp = json_response(conn_appeal, 201)
      assert appeal_resp["appeal"]["target_id"] == warning.id
      assert appeal_resp["appeal"]["status"] == "pending"

      # Duplicate appeal returns 409
      conn_dup =
        conn
        |> auth_conn(user)
        |> post(~p"/api/appeals", appeal_params)

      assert response(conn_dup, 409)

      # GET /api/appeals/mine
      conn_mine =
        conn
        |> auth_conn(user)
        |> get(~p"/api/appeals/mine")

      mine_resp = json_response(conn_mine, 200)
      assert is_list(mine_resp["appeals"])
      assert length(mine_resp["appeals"]) >= 1

      # GET /api/my/infractions
      conn_infr =
        conn
        |> auth_conn(user)
        |> get(~p"/api/my/infractions")

      infr_resp = json_response(conn_infr, 200)
      assert is_list(infr_resp["warnings"])
      assert infr_resp["active_points"] >= 2
      assert is_list(infr_resp["appeals"])
    end
  end

  # =========================================================================
  # ModerationController Tests
  # =========================================================================
  describe "ModerationController access control" do
    test "rejects unauthenticated and non-staff users", %{conn: conn} do
      non_staff = create_user()

      # Unauthenticated -> 401
      conn_unauth = get(fresh_conn(conn), ~p"/api/mod/reports")
      assert response(conn_unauth, 401)

      # Authenticated non-staff -> 403
      conn_non_staff =
        conn
        |> auth_conn(non_staff)
        |> get(~p"/api/mod/reports")

      assert response(conn_non_staff, 403)
    end
  end

  describe "ModerationController reports workflow" do
    test "list, show, assign, resolve, and dismiss reports", %{conn: conn} do
      staff = create_staff_user()
      reporter = create_user()
      {_forum, _thread, post} = create_forum_and_thread(reporter)

      {:ok, report} =
        Moderation.create_report(
          %{
            reason: "inappropriate",
            description: "Violates conduct",
            reportable_type: "post",
            reportable_id: post.id
          },
          reporter
        )

      # 1. List reports
      conn_list =
        conn
        |> auth_conn(staff)
        |> get(~p"/api/mod/reports")

      list_resp = json_response(conn_list, 200)
      assert is_list(list_resp["reports"])
      assert list_resp["counts"]["pending"] >= 1

      # 2. Show report
      conn_show =
        conn
        |> auth_conn(staff)
        |> get(~p"/api/mod/reports/#{report.id}")

      assert json_response(conn_show, 200)["report"]["id"] == report.id

      # 3. Assign report
      conn_assign =
        conn
        |> auth_conn(staff)
        |> put(~p"/api/mod/reports/#{report.id}/assign", %{"moderator_id" => staff.id})

      assert json_response(conn_assign, 200)["report"]["assigned_to"]["id"] == staff.id

      # 4. Resolve report
      conn_resolve =
        conn
        |> auth_conn(staff)
        |> put(~p"/api/mod/reports/#{report.id}/resolve", %{"resolution_note" => "Warned user"})

      resolve_resp = json_response(conn_resolve, 200)
      assert resolve_resp["report"]["status"] == "resolved"
      assert resolve_resp["report"]["resolution_note"] == "Warned user"

      # 5. Dismiss another report
      {:ok, report2} =
        Moderation.create_report(
          %{
            reason: "other",
            reportable_type: "post",
            reportable_id: post.id
          },
          reporter
        )

      conn_dismiss =
        conn
        |> auth_conn(staff)
        |> put(~p"/api/mod/reports/#{report2.id}/dismiss", %{"resolution_note" => "No violation"})

      assert json_response(conn_dismiss, 200)["report"]["status"] == "dismissed"
    end
  end

  describe "ModerationController bans and warnings" do
    test "create and revoke bans and warnings, inspect infractions", %{conn: conn} do
      staff = create_staff_user()
      target_user = create_user()

      # 1. Create ban
      ban_params = %{
        "ban" => %{
          "user_id" => target_user.id,
          "reason" => "Repeated rule violations",
          "type" => "temporary",
          "expires_at" => "2030-01-01T00:00:00Z"
        }
      }

      conn_ban =
        conn
        |> auth_conn(staff)
        |> post(~p"/api/mod/bans", ban_params)

      ban_resp = json_response(conn_ban, 201)
      ban_id = ban_resp["ban"]["id"]
      assert ban_resp["ban"]["reason"] == "Repeated rule violations"
      assert ban_resp["ban"]["is_active"] == true

      # 2. List bans
      conn_bans =
        conn
        |> auth_conn(staff)
        |> get(~p"/api/mod/bans?user_id=#{target_user.id}")

      assert length(json_response(conn_bans, 200)["bans"]) >= 1

      # 3. Revoke ban
      conn_unban =
        conn
        |> auth_conn(staff)
        |> put(~p"/api/mod/bans/#{ban_id}/revoke")

      assert json_response(conn_unban, 200)["ban"]["is_active"] == false

      # 4. Create warning
      warning_params = %{
        "warning" => %{
          "user_id" => target_user.id,
          "reason" => "Spamming shoutbox",
          "points" => 3
        }
      }

      conn_warn =
        conn
        |> auth_conn(staff)
        |> post(~p"/api/mod/warnings", warning_params)

      warn_resp = json_response(conn_warn, 201)
      warning_id = warn_resp["warning"]["id"]
      assert warn_resp["warning"]["points"] == 3

      # 5. List warnings
      conn_warns =
        conn
        |> auth_conn(staff)
        |> get(~p"/api/mod/warnings?user_id=#{target_user.id}")

      assert length(json_response(conn_warns, 200)["warnings"]) >= 1

      # 6. User infractions overview
      conn_infr =
        conn
        |> auth_conn(staff)
        |> get(~p"/api/mod/users/#{target_user.id}/infractions")

      infr_resp = json_response(conn_infr, 200)
      assert infr_resp["active_points"] == 3

      # 7. Revoke warning
      conn_revoke_warn =
        conn
        |> auth_conn(staff)
        |> put(~p"/api/mod/warnings/#{warning_id}/revoke")

      assert json_response(conn_revoke_warn, 200)["warning"]["is_active"] == false
    end
  end

  describe "ModerationController mod notes and logs" do
    test "create, list, and delete mod notes; list mod logs", %{conn: conn} do
      staff = create_staff_user()
      target_user = create_user()

      # Create note
      conn_create_note =
        conn
        |> auth_conn(staff)
        |> post(~p"/api/mod/users/#{target_user.id}/notes", %{"body" => "Under watch for spam"})

      note_resp = json_response(conn_create_note, 201)
      note_id = note_resp["note"]["id"]
      assert note_resp["note"]["body"] == "Under watch for spam"

      # List notes
      conn_list_notes =
        conn
        |> auth_conn(staff)
        |> get(~p"/api/mod/users/#{target_user.id}/notes")

      assert length(json_response(conn_list_notes, 200)["notes"]) >= 1

      # Delete note
      conn_del_note =
        conn
        |> auth_conn(staff)
        |> delete(~p"/api/mod/notes/#{note_id}")

      assert json_response(conn_del_note, 200)["ok"] == true

      # List mod logs
      conn_logs =
        conn
        |> auth_conn(staff)
        |> get(~p"/api/mod/logs")

      assert is_list(json_response(conn_logs, 200)["logs"])
    end
  end

  describe "ModerationController thread and post actions" do
    test "lock, unlock, pin, unpin, hide, unhide, move thread and hide post", %{conn: conn} do
      staff = create_staff_user()
      user = create_user()
      {_forum, thread, post} = create_forum_and_thread(user)

      # Create destination forum for move
      {:ok, cat2} =
        Forums.create_category(%{
          name: "Cat 2",
          slug: "cat-2-#{System.unique_integer([:positive])}",
          position: 2
        })

      {:ok, new_forum} =
        Forums.create_forum(%{
          name: "Forum 2",
          slug: "forum-2-#{System.unique_integer([:positive])}",
          category_id: cat2.id,
          position: 2
        })

      # Lock thread
      conn_lock = conn |> auth_conn(staff) |> put(~p"/api/mod/threads/#{thread.id}/lock")
      assert json_response(conn_lock, 200)["thread"]["is_locked"] == true

      # Unlock thread
      conn_unlock = conn |> auth_conn(staff) |> put(~p"/api/mod/threads/#{thread.id}/unlock")
      assert json_response(conn_unlock, 200)["thread"]["is_locked"] == false

      # Pin thread
      conn_pin = conn |> auth_conn(staff) |> put(~p"/api/mod/threads/#{thread.id}/pin")
      assert json_response(conn_pin, 200)["thread"]["is_pinned"] == true

      # Unpin thread
      conn_unpin = conn |> auth_conn(staff) |> put(~p"/api/mod/threads/#{thread.id}/unpin")
      assert json_response(conn_unpin, 200)["thread"]["is_pinned"] == false

      # Hide thread
      conn_hide_th =
        conn
        |> auth_conn(staff)
        |> put(~p"/api/mod/threads/#{thread.id}/hide", %{"reason" => "Under investigation"})

      assert json_response(conn_hide_th, 200)["ok"] == true

      # Unhide thread
      conn_unhide_th = conn |> auth_conn(staff) |> put(~p"/api/mod/threads/#{thread.id}/unhide")
      assert json_response(conn_unhide_th, 200)["ok"] == true

      # Move thread
      conn_move =
        conn
        |> auth_conn(staff)
        |> put(~p"/api/mod/threads/#{thread.id}/move", %{"forum_id" => new_forum.id})

      assert json_response(conn_move, 200)["ok"] == true
      moved_thread = Forums.get_thread!(thread.id)
      assert moved_thread.forum_id == new_forum.id

      # Hide post
      conn_hide_p =
        conn
        |> auth_conn(staff)
        |> put(~p"/api/mod/posts/#{post.id}/hide", %{"reason" => "Toxic content"})

      assert json_response(conn_hide_p, 200)["ok"] == true

      # Unhide post
      conn_unhide_p = conn |> auth_conn(staff) |> put(~p"/api/mod/posts/#{post.id}/unhide")
      assert json_response(conn_unhide_p, 200)["ok"] == true

      # Bulk action
      conn_bulk =
        conn
        |> auth_conn(staff)
        |> post(~p"/api/mod/threads/bulk", %{"action" => "lock", "thread_ids" => [thread.id]})

      assert json_response(conn_bulk, 200)["ok"] == true
    end
  end

  describe "ModerationController policies and dashboard" do
    test "manage policies and inspect dashboard workload and queue stats", %{conn: conn} do
      staff = create_staff_user()

      # Create policy
      policy_params = %{
        "policy" => %{
          "name" => "Anti-Harassment Policy",
          "description" => "Zero tolerance for bullying",
          "is_active" => true
        }
      }

      conn_create_pol =
        conn
        |> auth_conn(staff)
        |> post(~p"/api/mod/policies", policy_params)

      pol_resp = json_response(conn_create_pol, 201)
      policy_id = pol_resp["policy"]["id"]
      assert pol_resp["policy"]["name"] == "Anti-Harassment Policy"

      # List policies
      conn_list_pol =
        conn
        |> auth_conn(staff)
        |> get(~p"/api/mod/policies")

      assert length(json_response(conn_list_pol, 200)["policies"]) >= 1

      # Show policy
      conn_show_pol =
        conn
        |> auth_conn(staff)
        |> get(~p"/api/mod/policies/#{policy_id}")

      assert json_response(conn_show_pol, 200)["policy"]["id"] == policy_id

      # Update policy
      conn_update_pol =
        conn
        |> auth_conn(staff)
        |> put(~p"/api/mod/policies/#{policy_id}", %{
          "policy" => %{"name" => "Updated Anti-Harassment"}
        })

      assert json_response(conn_update_pol, 200)["policy"]["name"] == "Updated Anti-Harassment"

      # Delete policy
      conn_del_pol =
        conn
        |> auth_conn(staff)
        |> delete(~p"/api/mod/policies/#{policy_id}")

      assert json_response(conn_del_pol, 200)["ok"] == true

      # Dashboard workload
      conn_workload =
        conn
        |> auth_conn(staff)
        |> get(~p"/api/mod/dashboard/workload")

      assert json_response(conn_workload, 200)["workload"] != nil

      # Dashboard queue stats
      conn_queue =
        conn
        |> auth_conn(staff)
        |> get(~p"/api/mod/dashboard/queue")

      assert json_response(conn_queue, 200)["queue"] != nil
    end
  end
end
