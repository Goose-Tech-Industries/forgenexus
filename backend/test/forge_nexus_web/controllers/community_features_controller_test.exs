defmodule ForgeNexusWeb.CommunityFeaturesControllerTest do
  use ForgeNexusWeb.ConnCase, async: false

  alias ForgeNexus.{
    Accounts,
    Events,
    Forums,
    Governance,
    Guardian,
    Repo,
    Spaces,
    Themes,
    Wiki
  }

  alias ForgeNexusWeb.{
    AdminThemeController,
    BadgeController,
    EventController,
    ThemeController
  }

  defp fresh_conn(conn) do
    b3 = rem(System.unique_integer([:positive]), 250) + 1
    b4 = rem(System.unique_integer([:positive]), 250) + 1
    %{conn | remote_ip: {10, 0, b3, b4}}
  end

  defp create_user(attrs \\ %{}) do
    unique = System.unique_integer([:positive])

    default_attrs = %{
      username: "cf_u_#{unique}",
      email: "cf_u_#{unique}@example.com",
      password: "ValidPassword123!@#",
      display_name: "CF User #{unique}"
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
  # 1. BadgeController
  # =========================================================================
  describe "BadgeController" do
    test "GET /api/badges and /api/badges/user/:user_id", %{conn: conn} do
      user = create_user()
      unique = System.unique_integer([:positive])

      {:ok, badge} =
        Forums.create_badge(%{
          name: "Badge #{unique}",
          description: "Earned for testing",
          icon_emoji: "🎖️",
          is_active: true
        })

      # Public index
      conn_get = get(fresh_conn(conn), ~p"/api/badges")
      resp = json_response(conn_get, 200)
      assert is_list(resp["badges"])
      assert Enum.any?(resp["badges"], &(&1["id"] == badge.id))

      # User badges
      conn_user = get(fresh_conn(conn), ~p"/api/badges/user/#{user.id}")
      resp_user = json_response(conn_user, 200)
      assert is_list(resp_user["badges"])
    end

    test "admin actions: admin_index, create, update, delete, award, revoke", %{conn: conn} do
      admin = create_admin_user()
      user = create_user()
      unique = System.unique_integer([:positive])

      authed = auth_conn(conn, admin)

      # create badge
      conn_create =
        BadgeController.create(authed, %{
          "name" => "Admin Badge #{unique}",
          "description" => "Created by admin",
          "icon_emoji" => "🔥"
        })

      assert conn_create.status == 201
      badge_id = json_response(conn_create, 201)["badge"]["id"]

      # admin_index
      conn_admin_index = BadgeController.admin_index(authed, %{})
      assert conn_admin_index.status == 200
      assert Enum.any?(json_response(conn_admin_index, 200)["badges"], &(&1["id"] == badge_id))

      # update
      conn_update =
        BadgeController.update(authed, %{"id" => badge_id, "description" => "Updated desc"})

      assert conn_update.status == 200
      assert json_response(conn_update, 200)["badge"]["description"] == "Updated desc"

      # award badge
      conn_award =
        BadgeController.award(authed, %{
          "user_id" => user.id,
          "badge_id" => badge_id,
          "reason" => "Great testing"
        })

      assert json_response(conn_award, 200)["ok"] == true

      # revoke badge
      conn_revoke =
        BadgeController.revoke(authed, %{"user_id" => user.id, "badge_id" => badge_id})

      assert json_response(conn_revoke, 200)["ok"] == true

      # error branch for update
      conn_update_err =
        BadgeController.update(authed, %{"id" => badge_id, "category" => "invalid_category"})

      assert conn_update_err.status == 422

      # delete
      conn_del = BadgeController.delete(authed, %{"id" => badge_id})
      assert json_response(conn_del, 200)["ok"] == true

      # error branch for create
      conn_create_err = BadgeController.create(authed, %{"name" => ""})
      assert conn_create_err.status == 422
    end
  end

  # =========================================================================
  # 2. EmojiController
  # =========================================================================
  describe "EmojiController" do
    test "public index, admin CRUD endpoints", %{conn: conn} do
      admin = create_admin_user()
      unique = System.unique_integer([:positive])
      shortcode = "emoji_#{unique}"

      # Public index initially
      conn_pub = get(fresh_conn(conn), ~p"/api/emojis")
      assert json_response(conn_pub, 200)["emojis"] != nil

      # Admin create
      conn_create =
        conn
        |> auth_conn(admin)
        |> post(~p"/api/admin/emojis", %{
          "name" => "Test Emoji #{unique}",
          "shortcode" => shortcode,
          "image_url" => "https://example.com/#{shortcode}.png"
        })

      assert conn_create.status == 201
      emoji_id = json_response(conn_create, 201)["emoji"]["id"]

      # Admin index
      conn_admin_idx =
        conn
        |> auth_conn(admin)
        |> get(~p"/api/admin/emojis")

      assert Enum.any?(
               json_response(conn_admin_idx, 200)["emojis"],
               &(&1["id"] == emoji_id)
             )

      # Admin update
      conn_update =
        conn
        |> auth_conn(admin)
        |> put(~p"/api/admin/emojis/#{emoji_id}", %{"category" => "custom_cat"})

      assert json_response(conn_update, 200)["emoji"]["category"] == "custom_cat"

      # Admin create error (invalid shortcode format)
      conn_invalid =
        conn
        |> auth_conn(admin)
        |> post(~p"/api/admin/emojis", %{
          "name" => "Invalid",
          "shortcode" => "INVALID SHORTCODE!",
          "image_url" => "https://example.com/bad.png"
        })

      assert conn_invalid.status == 422

      # Admin delete
      conn_del =
        conn
        |> auth_conn(admin)
        |> delete(~p"/api/admin/emojis/#{emoji_id}")

      assert json_response(conn_del, 200)["ok"] == true
    end
  end

  # =========================================================================
  # 3. EventController
  # =========================================================================
  describe "EventController" do
    test "list, upcoming, show, and direct actions (create, update, delete, rsvp, suggestions)",
         %{conn: conn} do
      user = create_user()
      other_user = create_user()
      unique = System.unique_integer([:positive])

      now = DateTime.utc_now() |> DateTime.truncate(:second)
      ends = DateTime.add(now, 3600, :second)

      {:ok, event} =
        Events.create_event(%{
          title: "Controller Event #{unique}",
          starts_at: now,
          ends_at: ends,
          created_by_id: user.id
        })

      # Public index
      conn_idx = get(fresh_conn(conn), ~p"/api/events?month=#{now.month}&year=#{now.year}")
      assert json_response(conn_idx, 200)["events"] != nil

      # Upcoming
      conn_up = get(fresh_conn(conn), ~p"/api/events/upcoming")
      assert json_response(conn_up, 200)["events"] != nil

      # Show
      conn_show = get(fresh_conn(conn), ~p"/api/events/#{event.id}")
      resp_show = json_response(conn_show, 200)
      assert resp_show["event"]["id"] == event.id
      assert resp_show["rsvp_counts"] != nil

      # Direct create
      authed_user = auth_conn(conn, user)

      conn_create =
        EventController.create(authed_user, %{
          "title" => "Created Via Controller #{unique}",
          "starts_at" => now,
          "ends_at" => ends
        })

      assert conn_create.status == 201
      new_event_id = json_response(conn_create, 201)["event"]["id"]

      # Direct create validation failure
      conn_create_err = EventController.create(authed_user, %{"title" => ""})
      assert conn_create_err.status == 422

      # Direct update (owner allowed)
      conn_update =
        EventController.update(authed_user, %{
          "id" => new_event_id,
          "title" => "Updated Title #{unique}"
        })

      assert json_response(conn_update, 200)["event"]["title"] == "Updated Title #{unique}"

      # Direct update (non-owner forbidden)
      authed_other = auth_conn(conn, other_user)

      conn_update_forbid =
        EventController.update(authed_other, %{
          "id" => new_event_id,
          "title" => "Hacked Title"
        })

      assert conn_update_forbid.status == 403

      # Direct RSVP
      conn_rsvp =
        EventController.rsvp(authed_other, %{"id" => new_event_id, "status" => "going"})

      assert json_response(conn_rsvp, 200)["ok"] == true

      # Direct suggestions
      conn_sugg = EventController.suggestions(authed_user, %{})
      assert json_response(conn_sugg, 200)["suggestions"] != nil

      # Direct delete (non-owner forbidden)
      conn_del_forbid = EventController.delete(authed_other, %{"id" => new_event_id})
      assert conn_del_forbid.status == 403

      # Direct delete (owner allowed)
      conn_del_ok = EventController.delete(authed_user, %{"id" => new_event_id})
      assert json_response(conn_del_ok, 200)["ok"] == true
    end
  end

  # =========================================================================
  # 4. GovernanceController
  # =========================================================================
  describe "GovernanceController" do
    test "index, show, comments, and show_election", %{conn: conn} do
      user = create_user()
      unique = System.unique_integer([:positive])

      now = DateTime.utc_now() |> DateTime.truncate(:second)
      ends = DateTime.add(now, 86400 * 7, :second)

      {:ok, proposal} =
        Governance.create_proposal(%{
          title: "Proposal #{unique}",
          body: "Proposal description",
          type: "feature",
          status: "voting",
          voting_starts_at: now,
          voting_ends_at: ends,
          author_id: user.id
        })

      {:ok, _comment} =
        Governance.create_comment(%{
          proposal_id: proposal.id,
          user_id: user.id,
          body: "Great proposal!"
        })

      {:ok, election} =
        Governance.create_election(%{
          position: "Council Member",
          proposal_id: proposal.id,
          max_winners: 3,
          status: "voting"
        })

      # Index
      conn_idx = get(fresh_conn(conn), ~p"/api/governance/proposals")

      assert Enum.any?(
               json_response(conn_idx, 200)["proposals"],
               &(&1["id"] == proposal.id)
             )

      # Show
      conn_show = get(fresh_conn(conn), ~p"/api/governance/proposals/#{proposal.id}")
      resp_show = json_response(conn_show, 200)
      assert resp_show["proposal"]["id"] == proposal.id
      assert resp_show["results"] != nil

      # Show 404
      conn_not_found =
        get(fresh_conn(conn), ~p"/api/governance/proposals/#{Ecto.UUID.generate()}")

      assert conn_not_found.status == 404

      # Comments
      conn_comments =
        get(fresh_conn(conn), ~p"/api/governance/proposals/#{proposal.id}/comments")

      assert length(json_response(conn_comments, 200)["comments"]) >= 1

      # Show Election
      conn_elec = get(fresh_conn(conn), ~p"/api/governance/elections/#{election.id}")
      assert json_response(conn_elec, 200)["election_id"] == election.id
    end
  end

  # =========================================================================
  # 5. WikiController
  # =========================================================================
  describe "WikiController" do
    test "categories, index, show, revisions, and search", %{conn: conn} do
      user = create_user()
      unique = System.unique_integer([:positive])

      {:ok, cat} =
        Wiki.create_category(%{
          name: "Wiki Cat #{unique}",
          slug: "wiki-cat-#{unique}",
          position: 1
        })

      {:ok, page} =
        Wiki.create_page(
          %{
            title: "Wiki Page #{unique}",
            slug: "wiki-page-#{unique}",
            body: "Content for wiki page",
            category_id: cat.id,
            is_published: true
          },
          user.id
        )

      # Categories
      conn_cats = get(fresh_conn(conn), ~p"/api/wiki/categories")

      assert Enum.any?(
               json_response(conn_cats, 200)["categories"],
               &(&1["id"] == cat.id)
             )

      # Index
      conn_idx = get(fresh_conn(conn), ~p"/api/wiki/pages?category_id=#{cat.id}")
      assert Enum.any?(json_response(conn_idx, 200)["pages"], &(&1["id"] == page.id))

      # Index with no category_id
      conn_empty = get(fresh_conn(conn), ~p"/api/wiki/pages")
      assert json_response(conn_empty, 200)["pages"] == []

      # Show
      conn_show = get(fresh_conn(conn), ~p"/api/wiki/pages/#{page.slug}")
      assert json_response(conn_show, 200)["page"]["slug"] == page.slug

      # Show 404
      conn_404 = get(fresh_conn(conn), ~p"/api/wiki/pages/non-existent-slug-xyz")
      assert conn_404.status == 404

      # Revisions
      conn_rev = get(fresh_conn(conn), ~p"/api/wiki/pages/#{page.slug}/revisions")
      assert json_response(conn_rev, 200)["revisions"] != nil

      # Revisions 404
      conn_rev_404 =
        get(fresh_conn(conn), ~p"/api/wiki/pages/non-existent-slug-xyz/revisions")

      assert conn_rev_404.status == 404

      # Search
      conn_srch = get(fresh_conn(conn), ~p"/api/wiki/search?q=Wiki")
      assert is_list(json_response(conn_srch, 200)["results"])

      conn_srch_empty = get(fresh_conn(conn), ~p"/api/wiki/search")
      assert json_response(conn_srch_empty, 200)["results"] == []
    end
  end

  # =========================================================================
  # 6. SpaceController
  # =========================================================================
  describe "SpaceController" do
    test "index, show, and room_users", %{conn: conn} do
      unique = System.unique_integer([:positive])

      {:ok, map} =
        Spaces.create_map(%{
          name: "Virtual Space #{unique}",
          slug: "virtual-space-#{unique}",
          width: 800,
          height: 600,
          is_active: true
        })

      {:ok, room} =
        Spaces.create_room(%{
          map_id: map.id,
          name: "Main Room",
          type: "chat",
          x: 10,
          y: 10,
          width: 100,
          height: 100
        })

      # Index
      conn_idx = get(fresh_conn(conn), ~p"/api/spaces")
      assert Enum.any?(json_response(conn_idx, 200)["maps"], &(&1["id"] == map.id))

      # Show
      conn_show = get(fresh_conn(conn), ~p"/api/spaces/#{map.slug}")
      resp_show = json_response(conn_show, 200)
      assert resp_show["map"]["id"] == map.id
      assert Enum.any?(resp_show["rooms"], &(&1["id"] == room.id))

      # Show 404
      conn_404 = get(fresh_conn(conn), ~p"/api/spaces/non-existent-space-xyz")
      assert conn_404.status == 404

      # Room users
      conn_users = get(fresh_conn(conn), ~p"/api/spaces/rooms/#{room.id}/users")
      assert json_response(conn_users, 200)["users"] != nil
    end
  end

  # =========================================================================
  # 7. StatusController
  # =========================================================================
  describe "StatusController" do
    test "PUT /api/user/status updates status, custom emoji/text, and clear_custom", %{conn: conn} do
      user = create_user()

      # 1. Update presence status + custom text
      conn_update =
        conn
        |> auth_conn(user)
        |> put(~p"/api/user/status", %{
          "status" => "online",
          "custom_text" => "Building test coverage",
          "custom_emoji" => "🚀"
        })

      resp = json_response(conn_update, 200)
      assert resp["status"] == "online"
      assert resp["custom_status_text"] == "Building test coverage"
      assert resp["custom_status_emoji"] == "🚀"

      # 2. Clear custom status
      conn_clear =
        conn
        |> auth_conn(user)
        |> put(~p"/api/user/status", %{"clear_custom" => true})

      resp_clear = json_response(conn_clear, 200)
      assert resp_clear["custom_status_text"] == nil

      # 3. Invalid status value
      conn_err =
        conn
        |> auth_conn(user)
        |> put(~p"/api/user/status", %{"status" => "completely_invalid_status"})

      assert conn_err.status == 422
    end
  end

  # =========================================================================
  # 8. ThemeController & AdminThemeController
  # =========================================================================
  describe "ThemeController & AdminThemeController" do
    test "ThemeController index, show, and AdminThemeController lifecycle", %{conn: conn} do
      admin = create_admin_user()
      unique = System.unique_integer([:positive])

      # AdminThemeController create
      authed = auth_conn(conn, admin)

      conn_create =
        AdminThemeController.create(authed, %{
          "theme" => %{
            "name" => "Neon Cyber #{unique}",
            "slug" => "neon-cyber-#{unique}",
            "is_active" => true
          }
        })

      assert conn_create.status == 201
      theme_id = json_response(conn_create, 201)["theme"]["id"]

      # Public index
      conn_idx = get(fresh_conn(conn), ~p"/api/themes")
      assert Enum.any?(json_response(conn_idx, 200)["themes"], &(&1["id"] == theme_id))

      # Public show
      conn_show = get(fresh_conn(conn), ~p"/api/themes/#{theme_id}")
      assert json_response(conn_show, 200)["theme"]["id"] == theme_id

      # Admin update
      conn_update =
        AdminThemeController.update(authed, %{
          "id" => theme_id,
          "theme" => %{"description" => "Dark neon accents"}
        })

      assert conn_update.status == 200

      # Set default
      conn_def = AdminThemeController.set_default(authed, %{"id" => theme_id})
      assert conn_def.status == 200
      assert json_response(conn_def, 200)["theme"]["is_default"] == true

      # Cannot delete default theme
      conn_cant_del = AdminThemeController.delete(authed, %{"id" => theme_id})
      assert conn_cant_del.status == 422

      # AdminThemeController index
      conn_admin_idx = AdminThemeController.index(authed, %{})
      assert conn_admin_idx.status == 200

      # Create validation error
      conn_cs_err = AdminThemeController.create(authed, %{"theme" => %{"name" => ""}})
      assert conn_cs_err.status == 422

      # Direct ThemeController create/update tests
      theme_obj = Themes.get_theme!(theme_id)

      conn_tc_create =
        ThemeController.create(authed, %{
          "theme" => %{
            "name" => "Direct Theme #{unique}",
            "slug" => "direct-theme-#{unique}",
            "is_active" => true
          }
        })

      assert conn_tc_create.status == 201

      conn_tc_update =
        ThemeController.update(authed, %{
          "id" => theme_obj.id,
          "theme" => %{"description" => "Updated via ThemeController"}
        })

      assert conn_tc_update.status == 200
    end
  end

  # =========================================================================
  # 9. HousesController
  # =========================================================================
  describe "HousesController" do
    test "POST /api/signup/houses handles provisioning, missing fields, and changeset errors",
         %{conn: conn} do
      unique = System.unique_integer([:positive])

      # 1. Successful house signup
      conn_ok =
        post(fresh_conn(conn), ~p"/api/signup/houses", %{
          "founder_email" => "founder_#{unique}@example.com",
          "founder_password" => "ValidPassword123!@#",
          "founder_username" => "founder_#{unique}",
          "house_name" => "House of Wolves #{unique}",
          "house_slug" => "house-wolves-#{unique}",
          "creator_emails" => ["creator1_#{unique}@example.com", "creator2_#{unique}@example.com"]
        })

      assert conn_ok.status == 200
      resp = json_response(conn_ok, 200)
      assert resp["token"] != nil
      assert resp["community_id"] != nil
      assert resp["creator_count"] == 2
      assert length(resp["invitations"]) == 2

      # 2. Missing fields -> 400
      conn_missing =
        post(fresh_conn(conn), ~p"/api/signup/houses", %{
          "founder_email" => "founder_#{unique}@example.com"
        })

      assert conn_missing.status == 400
      assert json_response(conn_missing, 400)["error"] == "Missing fields"

      # 3. Validation error -> 422 (invalid email format)
      conn_invalid =
        post(fresh_conn(conn), ~p"/api/signup/houses", %{
          "founder_email" => "not-an-email",
          "founder_password" => "ValidPassword123!@#",
          "founder_username" => "founder_bad_#{unique}",
          "house_name" => "House #{unique}",
          "house_slug" => "house-bad-#{unique}",
          "creator_emails" => []
        })

      assert conn_invalid.status == 422
    end
  end

  # =========================================================================
  # 10. SignupController
  # =========================================================================
  describe "SignupController" do
    test "POST /api/signup/tier handles tier provisioning, missing fields, and invalid plans",
         %{conn: conn} do
      unique = System.unique_integer([:positive])

      # 1. Success tier provisioning (forum plan)
      conn_ok =
        post(fresh_conn(conn), ~p"/api/signup/tier", %{
          "email" => "signup_#{unique}@example.com",
          "password" => "ValidPassword123!@#",
          "username" => "signup_#{unique}",
          "community_slug" => "comm-slug-#{unique}",
          "community_name" => "Community #{unique}",
          "plan" => "forum"
        })

      assert conn_ok.status == 200
      resp = json_response(conn_ok, 200)
      assert resp["token"] != nil
      assert resp["user_id"] != nil
      assert resp["plan"] == "forum"

      # 2. Missing fields -> 400
      conn_missing =
        post(fresh_conn(conn), ~p"/api/signup/tier", %{
          "email" => "only_email@example.com"
        })

      assert conn_missing.status == 400
      assert json_response(conn_missing, 400)["error"] == "Missing fields"

      # 3. Invalid plan -> 422
      conn_bad_plan =
        post(fresh_conn(conn), ~p"/api/signup/tier", %{
          "email" => "bad_plan_#{unique}@example.com",
          "password" => "ValidPassword123!@#",
          "username" => "bad_plan_#{unique}",
          "community_slug" => "bad-plan-#{unique}",
          "community_name" => "Bad Plan Community",
          "plan" => "non_existent_plan_xyz"
        })

      assert conn_bad_plan.status == 422
      assert json_response(conn_bad_plan, 422)["error"] == "Invalid tier"
    end
  end
end
