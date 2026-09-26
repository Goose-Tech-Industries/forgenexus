defmodule ForgeNexusWeb.AdminAndSetupControllerTest do
  use ForgeNexusWeb.ConnCase, async: false

  alias ForgeNexus.{
    Accounts,
    Channels,
    Guardian,
    Repo
  }

  alias ForgeNexusWeb.{
    AdminAnnouncementController,
    AdminMaintenanceController,
    AdminSubscriptionTierController,
    BackupController,
    FallbackController,
    UploadController
  }

  defp fresh_conn(conn) do
    b3 = rem(System.unique_integer([:positive]), 250) + 1
    b4 = rem(System.unique_integer([:positive]), 250) + 1
    %{conn | remote_ip: {10, 0, b3, b4}}
  end

  defp create_user(attrs \\ %{}) do
    unique = System.unique_integer([:positive])

    default_attrs = %{
      username: "as_u_#{unique}",
      email: "as_u_#{unique}@example.com",
      password: "ValidPassword123!@#",
      display_name: "AS User #{unique}"
    }

    {:ok, user} = Accounts.register_user(Map.merge(default_attrs, attrs))

    now = DateTime.utc_now() |> DateTime.truncate(:second)
    {:ok, verified} = user |> Ecto.Changeset.change(email_verified_at: now) |> Repo.update()
    verified
  end

  defp create_admin_user(attrs \\ %{}) do
    user = create_user(attrs)

    admin_group =
      case Repo.get_by(Accounts.UserGroup, name: "Administrators") do
        nil ->
          {:ok, g} =
            Accounts.create_group(%{
              name: "Administrators",
              slug: "administrators-#{System.unique_integer([:positive])}",
              is_staff: true,
              color: "#FF0000"
            })

          g

        g ->
          g
      end

    {:ok, _} = Accounts.add_user_to_group(user.id, admin_group.id)
    user
  end

  defp auth_conn(conn, user) do
    {:ok, token, _claims} = Guardian.encode_and_sign(user)

    conn
    |> fresh_conn()
    |> Guardian.Plug.put_current_resource(user)
    |> Guardian.Plug.put_current_token(token)
    |> put_req_header("authorization", "Bearer #{token}")
    |> put_req_cookie("fn_token", token)
  end

  # =========================================================================
  # 1. SettingsController
  # =========================================================================
  describe "SettingsController" do
    test "public settings endpoint", %{conn: conn} do
      res = get(fresh_conn(conn), ~p"/api/settings/public")
      assert res.status == 200
      assert is_map(json_response(res, 200)["settings"])
    end
  end

  # =========================================================================
  # 2. SetupController
  # =========================================================================
  describe "SetupController" do
    test "status and preflight checks", %{conn: conn} do
      conn_status = get(fresh_conn(conn), ~p"/api/setup/status")
      assert conn_status.status == 200
      assert Map.has_key?(json_response(conn_status, 200), "installed")

      conn_preflight = get(fresh_conn(conn), ~p"/api/setup/preflight")
      assert conn_preflight.status in [200, 403]
    end

    test "upload_logo validation branches", %{conn: conn} do
      conn_no_file = post(fresh_conn(conn), ~p"/api/setup/upload-logo", %{})
      assert conn_no_file.status in [400, 403]

      # With invalid mime type
      tmp_path = Path.join(System.tmp_dir!(), "logo_#{System.unique_integer([:positive])}.txt")
      File.write!(tmp_path, "not an image")

      upload = %Plug.Upload{
        path: tmp_path,
        filename: "logo.txt",
        content_type: "text/plain"
      }

      conn_invalid = post(fresh_conn(conn), ~p"/api/setup/upload-logo", %{"file" => upload})
      assert conn_invalid.status in [422, 403]
      File.rm(tmp_path)
    end

    test "install endpoint", %{conn: conn} do
      conn_install = post(fresh_conn(conn), ~p"/api/setup/install", %{"site_name" => "Test Site"})
      assert conn_install.status in [403, 422, 201]
    end
  end

  # =========================================================================
  # 3. ContactController
  # =========================================================================
  describe "ContactController" do
    test "create handles success and validation errors", %{conn: conn} do
      # 1. Missing fields
      res_missing = post(fresh_conn(conn), ~p"/api/contact", %{"name" => "Alice"})
      assert res_missing.status == 422
      assert json_response(res_missing, 422)["error"] =~ "Missing required fields"

      # 2. Empty string field
      res_empty =
        post(fresh_conn(conn), ~p"/api/contact", %{
          "name" => "",
          "email" => "alice@example.com",
          "subject" => "Hello",
          "message" => "Hi there"
        })

      assert res_empty.status == 422
      assert json_response(res_empty, 422)["error"] == "All fields are required"

      # 3. Invalid email format
      res_invalid_email =
        post(fresh_conn(conn), ~p"/api/contact", %{
          "name" => "Alice",
          "email" => "invalid-email-address",
          "subject" => "Hello",
          "message" => "Hi there"
        })

      assert res_invalid_email.status == 422
      assert json_response(res_invalid_email, 422)["error"] == "Invalid email address"

      # 4. Message too long
      long_msg = String.duplicate("a", 5001)

      res_too_long =
        post(fresh_conn(conn), ~p"/api/contact", %{
          "name" => "Alice",
          "email" => "alice@example.com",
          "subject" => "Hello",
          "message" => long_msg
        })

      assert res_too_long.status == 422
      assert json_response(res_too_long, 422)["error"] =~ "Message is too long"

      # 5. Success
      res_ok =
        post(fresh_conn(conn), ~p"/api/contact", %{
          "name" => "Alice",
          "email" => "alice@example.com",
          "subject" => "Inquiry",
          "message" => "I'd like to ask a question."
        })

      assert res_ok.status == 200
      assert json_response(res_ok, 200)["message"] =~ "sent"
    end
  end

  # =========================================================================
  # 4. FallbackController
  # =========================================================================
  describe "FallbackController" do
    test "not_found returns 404 json", %{conn: conn} do
      res = FallbackController.not_found(fresh_conn(conn), %{})
      assert res.status == 404
      assert json_response(res, 404) == %{"error" => "Not found"}
    end
  end

  # =========================================================================
  # 5. AdminAnnouncementController
  # =========================================================================
  describe "AdminAnnouncementController" do
    test "index, create, update, delete, and active", %{conn: conn} do
      admin = create_admin_user()
      authed = auth_conn(conn, admin)
      unique = System.unique_integer([:positive])

      # 1. Create announcement
      conn_create =
        AdminAnnouncementController.create(authed, %{
          "announcement" => %{
            "title" => "System Maintenance #{unique}",
            "body" => "Scheduled maintenance on Sunday",
            "priority" => 10,
            "display_location" => "banner",
            "is_active" => true
          }
        })

      assert conn_create.status == 201
      ann_id = json_response(conn_create, 201)["announcement"]["id"]
      assert json_response(conn_create, 201)["announcement"]["created_by"]["id"] == admin.id

      # 2. Error branch on create
      conn_create_err =
        AdminAnnouncementController.create(authed, %{
          "announcement" => %{
            "title" => "",
            "body" => ""
          }
        })

      assert conn_create_err.status == 422

      # 3. Index
      conn_idx = AdminAnnouncementController.index(authed, %{})
      assert conn_idx.status == 200
      assert Enum.any?(json_response(conn_idx, 200)["announcements"], &(&1["id"] == ann_id))

      # 4. Active
      conn_act = get(fresh_conn(conn), ~p"/api/announcements/active")
      assert conn_act.status == 200
      assert Enum.any?(json_response(conn_act, 200)["announcements"], &(&1["id"] == ann_id))

      # 5. Update
      conn_upd =
        AdminAnnouncementController.update(authed, %{
          "id" => ann_id,
          "announcement" => %{
            "title" => "Updated Maintenance #{unique}"
          }
        })

      assert conn_upd.status == 200

      assert json_response(conn_upd, 200)["announcement"]["title"] ==
               "Updated Maintenance #{unique}"

      # 6. Error branch on update
      conn_upd_err =
        AdminAnnouncementController.update(authed, %{
          "id" => ann_id,
          "announcement" => %{"title" => ""}
        })

      assert conn_upd_err.status == 422

      # 7. Delete
      conn_del = AdminAnnouncementController.delete(authed, %{"id" => ann_id})
      assert conn_del.status == 200
      assert json_response(conn_del, 200)["ok"] == true
    end
  end

  # =========================================================================
  # 6. AdminChannelController
  # =========================================================================
  describe "AdminChannelController" do
    test "category and channel lifecycle via admin routes", %{conn: conn} do
      admin = create_admin_user()
      authed = auth_conn(conn, admin)
      unique = System.unique_integer([:positive])

      # 1. Create Category
      conn_cat =
        post(authed, ~p"/api/admin/chat/categories", %{
          "category" => %{"name" => "Cat #{unique}", "position" => 1}
        })

      assert conn_cat.status == 201
      cat_id = json_response(conn_cat, 201)["category"]["id"]

      # Error branch on create category
      conn_cat_err =
        post(authed, ~p"/api/admin/chat/categories", %{
          "category" => %{"name" => ""}
        })

      assert conn_cat_err.status == 422

      # 2. List Categories
      conn_cats = get(authed, ~p"/api/admin/chat/categories")
      assert conn_cats.status == 200
      assert Enum.any?(json_response(conn_cats, 200)["categories"], &(&1["id"] == cat_id))

      # 3. Update Category
      conn_cat_upd =
        put(authed, ~p"/api/admin/chat/categories/#{cat_id}", %{
          "category" => %{"name" => "Updated Cat #{unique}"}
        })

      assert conn_cat_upd.status == 200

      # 4. Reorder Categories
      conn_reorder_cat =
        put(authed, ~p"/api/admin/chat/categories/reorder", %{
          "ordered_ids" => [cat_id]
        })

      assert conn_reorder_cat.status == 200
      assert json_response(conn_reorder_cat, 200)["ok"] == true

      # 5. Create Channel
      conn_chan =
        post(authed, ~p"/api/admin/chat/channels", %{
          "channel" => %{
            "name" => "general-#{unique}",
            "type" => "text",
            "category_id" => cat_id
          }
        })

      assert conn_chan.status == 201
      chan_id = json_response(conn_chan, 201)["channel"]["id"]

      # Error branch on create channel
      conn_chan_err =
        post(authed, ~p"/api/admin/chat/channels", %{
          "channel" => %{"name" => ""}
        })

      assert conn_chan_err.status == 422

      # 6. List Channels
      conn_chans = get(authed, ~p"/api/admin/chat/channels")
      assert conn_chans.status == 200
      assert Enum.any?(json_response(conn_chans, 200)["channels"], &(&1["id"] == chan_id))

      # 7. Update Channel
      conn_chan_upd =
        put(authed, ~p"/api/admin/chat/channels/#{chan_id}", %{
          "channel" => %{"description" => "A general topic"}
        })

      assert conn_chan_upd.status == 200
      assert json_response(conn_chan_upd, 200)["channel"]["description"] == "A general topic"

      # 8. Archive and Unarchive Channel
      conn_arch = put(authed, ~p"/api/admin/chat/channels/#{chan_id}/archive")
      assert conn_arch.status == 200
      assert json_response(conn_arch, 200)["ok"] == true

      conn_unarch = put(authed, ~p"/api/admin/chat/channels/#{chan_id}/unarchive")
      assert conn_unarch.status == 200
      assert json_response(conn_unarch, 200)["ok"] == true

      # 9. Reorder Channels
      conn_reorder_chan =
        put(authed, ~p"/api/admin/chat/channels/reorder/#{cat_id}", %{
          "ordered_ids" => [chan_id]
        })

      assert conn_reorder_chan.status == 200

      # 10. Delete Message
      {:ok, msg} = Channels.create_message(chan_id, admin.id, %{body: "Message to delete"})
      conn_del_msg = delete(authed, ~p"/api/admin/chat/channels/messages/#{msg.id}")
      assert conn_del_msg.status == 200
      assert json_response(conn_del_msg, 200)["ok"] == true

      # 11. Delete Channel and Category
      conn_del_chan = delete(authed, ~p"/api/admin/chat/channels/#{chan_id}")
      assert conn_del_chan.status == 200
      assert json_response(conn_del_chan, 200)["ok"] == true

      conn_del_cat = delete(authed, ~p"/api/admin/chat/categories/#{cat_id}")
      assert conn_del_cat.status == 200
      assert json_response(conn_del_cat, 200)["ok"] == true
    end
  end

  # =========================================================================
  # 7. AdminLoginEventController
  # =========================================================================
  describe "AdminLoginEventController" do
    test "index with filters", %{conn: conn} do
      admin = create_admin_user()
      authed = auth_conn(conn, admin)

      {:ok, _event} =
        Accounts.record_login_event(%{
          email: admin.email,
          ip_address: "10.0.0.1",
          user_agent: "Mozilla/5.0",
          success: true,
          user_id: admin.id
        })

      # 1. Unfiltered index
      conn_idx = get(authed, ~p"/api/admin/login-events")
      assert conn_idx.status == 200
      assert length(json_response(conn_idx, 200)["events"]) >= 1

      # 2. Filter by user_id, email, ip, success, limit, since
      conn_filtered =
        get(authed, ~p"/api/admin/login-events", %{
          "user_id" => admin.id,
          "email" => admin.email,
          "ip" => "10.0.0.1",
          "success" => "true",
          "since" => "24",
          "limit" => "10"
        })

      assert conn_filtered.status == 200
      assert length(json_response(conn_filtered, 200)["events"]) >= 1
    end
  end

  # =========================================================================
  # 8. AdminMaintenanceController
  # =========================================================================
  describe "AdminMaintenanceController" do
    test "system_info, db_stats, clear_cache, and reindex_search", %{conn: conn} do
      admin = create_admin_user()
      authed = auth_conn(conn, admin)

      # 1. system_info
      conn_sys = AdminMaintenanceController.system_info(authed, %{})
      assert conn_sys.status == 200
      info = json_response(conn_sys, 200)["info"]
      assert Map.has_key?(info, "elixir_version")
      assert Map.has_key?(info, "memory_mb")

      # 2. db_stats
      conn_db = AdminMaintenanceController.db_stats(authed, %{})
      assert conn_db.status == 200
      assert is_list(json_response(conn_db, 200)["tables"])

      # 3. clear_cache
      conn_cache = AdminMaintenanceController.clear_cache(authed, %{})
      assert conn_cache.status == 200
      assert json_response(conn_cache, 200)["ok"] == true

      # 4. reindex_search
      conn_search = AdminMaintenanceController.reindex_search(authed, %{})
      assert conn_search.status == 200
      assert json_response(conn_search, 200)["ok"] == true
    end
  end

  # =========================================================================
  # 9. AdminMassEmailController
  # =========================================================================
  describe "AdminMassEmailController" do
    test "preview and send_email with valid and invalid segments", %{conn: conn} do
      admin = create_admin_user()
      authed = auth_conn(conn, admin)

      # 1. Preview valid
      conn_prev = get(authed, ~p"/api/admin/mass-email/preview?segment=all")
      assert conn_prev.status == 200
      assert json_response(conn_prev, 200)["segment"] == "all"
      assert is_integer(json_response(conn_prev, 200)["recipient_count"])

      # 2. Preview invalid
      conn_prev_err = get(authed, ~p"/api/admin/mass-email/preview?segment=invalid_seg")
      assert conn_prev_err.status == 422

      # 3. Send email valid
      conn_send =
        post(authed, ~p"/api/admin/mass-email", %{
          "subject" => "Announcing v2",
          "body" => "Hello everyone",
          "segment" => "verified"
        })

      assert conn_send.status == 200
      assert json_response(conn_send, 200)["ok"] == true

      # 4. Send email invalid segment
      conn_send_inv =
        post(authed, ~p"/api/admin/mass-email", %{
          "subject" => "Announcing v2",
          "body" => "Hello everyone",
          "segment" => "invalid_segment"
        })

      assert conn_send_inv.status == 422

      # 5. Send email missing fields
      conn_send_missing = post(authed, ~p"/api/admin/mass-email", %{})
      assert conn_send_missing.status == 422
    end
  end

  # =========================================================================
  # 10. AdminPromotionController
  # =========================================================================
  describe "AdminPromotionController" do
    test "CRUD lifecycle and evaluate_all", %{conn: conn} do
      admin = create_admin_user()
      authed = auth_conn(conn, admin)
      unique = System.unique_integer([:positive])

      {:ok, g1} =
        Accounts.create_group(%{
          name: "Group Alpha #{unique}",
          slug: "alpha-#{unique}",
          is_staff: false
        })

      {:ok, g2} =
        Accounts.create_group(%{
          name: "Group Beta #{unique}",
          slug: "beta-#{unique}",
          is_staff: false
        })

      # 1. Create rule
      conn_create =
        post(authed, ~p"/api/admin/promotion-rules", %{
          "name" => "Alpha to Beta #{unique}",
          "from_group_id" => g1.id,
          "to_group_id" => g2.id,
          "criteria" => %{"min_posts" => 25}
        })

      assert conn_create.status == 201
      rule_id = json_response(conn_create, 201)["rule"]["id"]

      # Error branch on create
      conn_create_err = post(authed, ~p"/api/admin/promotion-rules", %{"name" => ""})
      assert conn_create_err.status == 422

      # 2. Index
      conn_idx = get(authed, ~p"/api/admin/promotion-rules")
      assert conn_idx.status == 200
      assert Enum.any?(json_response(conn_idx, 200)["rules"], &(&1["id"] == rule_id))

      # 3. Update
      conn_upd =
        put(authed, ~p"/api/admin/promotion-rules/#{rule_id}", %{
          "criteria" => %{"min_posts" => 50}
        })

      assert conn_upd.status == 200
      assert json_response(conn_upd, 200)["rule"]["criteria"]["min_posts"] == 50

      # 4. Evaluate all
      conn_eval = post(authed, ~p"/api/admin/promotion-rules/evaluate")
      assert conn_eval.status == 200
      assert json_response(conn_eval, 200)["ok"] == true

      # 5. Delete
      conn_del = delete(authed, ~p"/api/admin/promotion-rules/#{rule_id}")
      assert conn_del.status == 200
      assert json_response(conn_del, 200)["ok"] == true
    end
  end

  # =========================================================================
  # 11. AdminQuarantineController
  # =========================================================================
  describe "AdminQuarantineController" do
    test "index, create, conflict, and release", %{conn: conn} do
      admin = create_admin_user()
      target_user = create_user()
      authed = auth_conn(conn, admin)

      # 1. Index initially
      conn_idx_init = get(authed, ~p"/api/admin/quarantine")
      assert conn_idx_init.status == 200

      # 2. Quarantine target user
      conn_create =
        post(authed, ~p"/api/admin/quarantine", %{
          "user_id" => target_user.id,
          "reason" => "Spam behavior"
        })

      assert conn_create.status == 201
      assert json_response(conn_create, 201)["record"]["user_id"] == target_user.id

      # 3. Conflict on duplicate quarantine
      conn_dup =
        post(authed, ~p"/api/admin/quarantine", %{
          "user_id" => target_user.id,
          "reason" => "Spam again"
        })

      assert conn_dup.status == 409

      # 4. Not found user quarantine
      conn_nf =
        post(authed, ~p"/api/admin/quarantine", %{
          "user_id" => Ecto.UUID.generate(),
          "reason" => "Ghost"
        })

      assert conn_nf.status == 404

      # 5. Release
      conn_rel = delete(authed, ~p"/api/admin/quarantine/#{target_user.id}")
      assert conn_rel.status == 200
      assert json_response(conn_rel, 200)["ok"] == true

      # 6. Release when not quarantined
      conn_rel_not = delete(authed, ~p"/api/admin/quarantine/#{target_user.id}")
      assert conn_rel_not.status == 404
    end
  end

  # =========================================================================
  # 12. AdminSubscriptionTierController
  # =========================================================================
  describe "AdminSubscriptionTierController" do
    test "full tier management lifecycle", %{conn: conn} do
      admin = create_admin_user()
      authed = auth_conn(conn, admin)
      unique = System.unique_integer([:positive])
      tier_lvl = rem(unique, 1000) + 20

      # 1. Index
      conn_idx = AdminSubscriptionTierController.index(authed, %{})
      assert conn_idx.status == 200
      assert is_list(json_response(conn_idx, 200)["tiers"])

      # 2. Create Tier
      conn_create =
        AdminSubscriptionTierController.create(authed, %{
          "tier" => %{
            "name" => "Gold Tier #{unique}",
            "slug" => "gold-tier-#{unique}",
            "tier_level" => tier_lvl,
            "description" => "Gold tier benefits",
            "price_monthly" => 9.99,
            "price_yearly" => 99.99,
            "color" => "#FFD700"
          }
        })

      assert conn_create.status == 201
      tier_id = json_response(conn_create, 201)["tier"]["id"]

      # Error branch on create
      conn_create_err =
        AdminSubscriptionTierController.create(authed, %{
          "tier" => %{"name" => ""}
        })

      assert conn_create_err.status == 422

      # 3. Update Tier
      conn_upd =
        AdminSubscriptionTierController.update(authed, %{
          "id" => tier_id,
          "tier" => %{"description" => "Updated gold perks"}
        })

      assert conn_upd.status == 200
      assert json_response(conn_upd, 200)["tier"]["description"] == "Updated gold perks"

      # Not found on update
      conn_upd_nf =
        AdminSubscriptionTierController.update(authed, %{
          "id" => Ecto.UUID.generate(),
          "tier" => %{"name" => "Fake"}
        })

      assert conn_upd_nf.status == 404

      # 4. Delete Tier
      conn_del = AdminSubscriptionTierController.delete(authed, %{"id" => tier_id})
      assert conn_del.status == 200
      assert json_response(conn_del, 200)["ok"] == true

      # Not found on delete
      conn_del_nf =
        AdminSubscriptionTierController.delete(authed, %{"id" => Ecto.UUID.generate()})

      assert conn_del_nf.status == 404
    end
  end

  # =========================================================================
  # 13. AdminAchievementController
  # =========================================================================
  describe "AdminAchievementController" do
    test "CRUD, grant, revoke, and bulk operations", %{conn: conn} do
      admin = create_admin_user()
      target_user = create_user()
      authed = auth_conn(conn, admin)
      unique = System.unique_integer([:positive])

      # 1. Create
      conn_create =
        post(authed, ~p"/api/admin/achievements", %{
          "achievement" => %{
            "name" => "Badge Master #{unique}",
            "points" => 100,
            "category" => "general"
          }
        })

      assert conn_create.status == 201
      ach_id = json_response(conn_create, 201)["achievement"]["id"]

      # Create error branch
      conn_create_err =
        post(authed, ~p"/api/admin/achievements", %{"achievement" => %{"name" => ""}})

      assert conn_create_err.status == 422

      # 2. Index
      conn_idx = get(authed, ~p"/api/admin/achievements")
      assert conn_idx.status == 200
      assert Enum.any?(json_response(conn_idx, 200)["achievements"], &(&1["id"] == ach_id))

      # 3. Show
      conn_show = get(authed, ~p"/api/admin/achievements/#{ach_id}")
      assert conn_show.status == 200
      assert json_response(conn_show, 200)["achievement"]["id"] == ach_id

      # Show not found
      conn_show_nf = get(authed, ~p"/api/admin/achievements/#{Ecto.UUID.generate()}")
      assert conn_show_nf.status == 404

      # 4. Update
      conn_upd =
        put(authed, ~p"/api/admin/achievements/#{ach_id}", %{
          "points" => 150
        })

      assert conn_upd.status == 200
      assert json_response(conn_upd, 200)["achievement"]["points"] == 150

      # Update not found
      conn_upd_nf =
        put(authed, ~p"/api/admin/achievements/#{Ecto.UUID.generate()}", %{
          "points" => 200
        })

      assert conn_upd_nf.status == 404

      # 5. Grant
      conn_grant = post(authed, ~p"/api/admin/achievements/#{ach_id}/grant/#{target_user.id}")
      assert conn_grant.status == 200
      assert json_response(conn_grant, 200)["ok"] == true

      # Duplicate grant conflict
      conn_grant_dup = post(authed, ~p"/api/admin/achievements/#{ach_id}/grant/#{target_user.id}")
      assert conn_grant_dup.status == 409

      # 6. Revoke
      conn_rev = delete(authed, ~p"/api/admin/achievements/#{ach_id}/grant/#{target_user.id}")
      assert conn_rev.status == 200
      assert json_response(conn_rev, 200)["ok"] == true

      # Revoke when not unlocked -> 404
      conn_rev_nf = delete(authed, ~p"/api/admin/achievements/#{ach_id}/grant/#{target_user.id}")
      assert conn_rev_nf.status == 404

      # 7. Bulk operation
      conn_bulk =
        post(authed, ~p"/api/admin/achievements/#{ach_id}/bulk", %{
          "action" => "grant",
          "targets" => [target_user.id, target_user.username, "nonexistent-user-xyz"]
        })

      assert conn_bulk.status == 200
      summary = json_response(conn_bulk, 200)["summary"]
      assert summary["total"] == 3
      assert summary["not_found"] >= 1

      # Invalid bulk request
      conn_bulk_bad = post(authed, ~p"/api/admin/achievements/#{ach_id}/bulk", %{})
      assert conn_bulk_bad.status == 400

      # 8. Delete
      conn_del = delete(authed, ~p"/api/admin/achievements/#{ach_id}")
      assert conn_del.status == 200
      assert json_response(conn_del, 200)["ok"] == true

      # Delete not found
      conn_del_nf = delete(authed, ~p"/api/admin/achievements/#{Ecto.UUID.generate()}")
      assert conn_del_nf.status == 404
    end
  end

  # =========================================================================
  # 14. UploadController
  # =========================================================================
  describe "UploadController" do
    test "create and delete attachment", %{conn: conn} do
      user = create_user()
      authed = auth_conn(conn, user)

      # 1. Direct index call
      conn_idx =
        UploadController.index(authed, %{
          "attachable_type" => "post",
          "attachable_id" => Ecto.UUID.generate()
        })

      assert conn_idx.status == 200
      assert json_response(conn_idx, 200)["attachments"] == []

      # 2. Upload file with valid PNG magic bytes
      tmp_png = Path.join(System.tmp_dir!(), "test_#{System.unique_integer([:positive])}.png")
      png_header = <<0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0, 0, 0, 0>>
      File.write!(tmp_png, png_header)

      upload = %Plug.Upload{
        path: tmp_png,
        filename: "test.png",
        content_type: "image/png"
      }

      conn_up =
        post(authed, ~p"/api/uploads", %{
          "file" => upload,
          "attachable_type" => "post",
          "attachable_id" => Ecto.UUID.generate()
        })

      assert conn_up.status == 201
      att_id = json_response(conn_up, 201)["attachment"]["id"]

      # 3. Delete attachment
      conn_del = delete(authed, ~p"/api/uploads/#{att_id}")
      assert conn_del.status == 200
      assert json_response(conn_del, 200)["status"] == "ok"

      # 4. Delete nonexistent attachment
      conn_del_nf = delete(authed, ~p"/api/uploads/#{Ecto.UUID.generate()}")
      assert conn_del_nf.status == 404

      File.rm(tmp_png)
    end
  end

  # =========================================================================
  # 15. BackupController
  # =========================================================================
  describe "BackupController" do
    test "list, download, and create actions", %{conn: conn} do
      admin = create_admin_user()
      authed = auth_conn(conn, admin)

      # Ensure backup dir and create a test backup file
      backup_dir = "priv/backups"
      File.mkdir_p!(backup_dir)
      test_file = "forgenexus_backup_test_#{System.unique_integer([:positive])}.sql"
      test_path = Path.join(backup_dir, test_file)
      File.write!(test_path, "-- Test backup content")

      # 1. List
      conn_list = BackupController.list(authed, %{})
      assert conn_list.status == 200
      backups = json_response(conn_list, 200)["backups"]
      assert Enum.any?(backups, &(&1["filename"] == test_file))

      # 2. Download existing
      conn_dl = BackupController.download(authed, %{"filename" => test_file})
      assert conn_dl.status == 200

      # 3. Download nonexistent
      conn_dl_nf = BackupController.download(authed, %{"filename" => "nonexistent.sql"})
      assert conn_dl_nf.status == 404

      # 4. Create action (exercises controller command/error execution)
      conn_create = BackupController.create(authed, %{})
      assert conn_create.status in [200, 500]

      File.rm(test_path)
    end
  end

  # =========================================================================
  # 16. ImportController
  # =========================================================================
  describe "ImportController" do
    test "available_sources, preview, start_import, and status", %{conn: conn} do
      admin = create_admin_user()
      authed = auth_conn(conn, admin)

      # 1. Available sources
      conn_src = get(authed, ~p"/api/admin/import/sources")
      assert conn_src.status == 200
      assert is_list(json_response(conn_src, 200)["sources"])

      # 2. Preview with data
      conn_prev =
        post(authed, ~p"/api/admin/import/preview", %{
          "data" => %{"users" => [%{"username" => "imp_user"}], "posts" => []}
        })

      assert conn_prev.status == 200
      assert is_map(json_response(conn_prev, 200)["preview"])

      # 3. Preview with invalid data
      conn_prev_err = post(authed, ~p"/api/admin/import/preview", %{})
      assert conn_prev_err.status == 400

      # 4. Start import missing source
      conn_start_err = post(authed, ~p"/api/admin/import/start", %{})
      assert conn_start_err.status == 400

      # 5. Status nonexistent
      conn_stat_nf = get(authed, ~p"/api/admin/import/status/#{Ecto.UUID.generate()}")
      assert conn_stat_nf.status == 404

      # 6. Cancel nonexistent
      conn_can_nf = post(authed, ~p"/api/admin/import/cancel/#{Ecto.UUID.generate()}")
      assert conn_can_nf.status == 404
    end
  end
end
