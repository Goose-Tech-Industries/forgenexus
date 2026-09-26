defmodule ForgeNexusWeb.AdminControllerTest do
  use ForgeNexusWeb.ConnCase, async: false

  alias ForgeNexus.Accounts
  alias ForgeNexus.Guardian
  alias ForgeNexus.Repo

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
    |> put_req_header("authorization", "Bearer #{token}")
    |> put_req_cookie("fn_token", token)
  end

  # =========================================================================
  # Access Control Tests
  # =========================================================================
  describe "Admin route access control" do
    test "rejects unauthenticated and non-admin requests", %{conn: conn} do
      non_admin = create_user()

      # Unauthenticated -> 401
      conn_unauth = get(fresh_conn(conn), ~p"/api/admin/settings")
      assert response(conn_unauth, 401)

      # Non-admin -> 403
      conn_forbidden =
        conn
        |> auth_conn(non_admin)
        |> get(~p"/api/admin/settings")

      assert response(conn_forbidden, 403)
    end
  end

  # =========================================================================
  # AdminSettingsController Tests
  # =========================================================================
  describe "AdminSettingsController" do
    test "GET and PUT /api/admin/settings", %{conn: conn} do
      admin = create_admin_user()

      # 1. GET settings
      conn_get =
        conn
        |> auth_conn(admin)
        |> get(~p"/api/admin/settings")

      get_resp = json_response(conn_get, 200)
      assert get_resp["settings"] != nil

      # 2. PUT settings
      conn_put =
        conn
        |> auth_conn(admin)
        |> put(~p"/api/admin/settings", %{"settings" => %{"site_name" => "ForgeNexus Admin Test"}})

      put_resp = json_response(conn_put, 200)
      assert put_resp["settings"] != nil
    end
  end

  # =========================================================================
  # AdminForumController Tests
  # =========================================================================
  describe "AdminForumController" do
    test "CRUD for categories and forums", %{conn: conn} do
      admin = create_admin_user()
      unique = System.unique_integer([:positive])

      # 1. List all
      conn_list =
        conn
        |> auth_conn(admin)
        |> get(~p"/api/admin/forums")

      assert is_list(json_response(conn_list, 200)["categories"])

      # 2. Create Category
      cat_params = %{
        "category" => %{
          "name" => "Admin Cat #{unique}",
          "slug" => "admin-cat-#{unique}",
          "description" => "Category for admin tests",
          "position" => 1
        }
      }

      conn_cat =
        conn
        |> auth_conn(admin)
        |> post(~p"/api/admin/categories", cat_params)

      cat_resp = json_response(conn_cat, 201)
      cat_id = cat_resp["category"]["id"]
      assert cat_resp["category"]["name"] == "Admin Cat #{unique}"

      # 3. Update Category
      conn_cat_up =
        conn
        |> auth_conn(admin)
        |> put(~p"/api/admin/categories/#{cat_id}", %{
          "category" => %{"name" => "Renamed Cat #{unique}"}
        })

      assert json_response(conn_cat_up, 200)["category"]["name"] == "Renamed Cat #{unique}"

      # 4. Create Forum
      forum_params = %{
        "forum" => %{
          "name" => "Admin Forum #{unique}",
          "slug" => "admin-forum-#{unique}",
          "description" => "Forum for admin tests",
          "category_id" => cat_id,
          "position" => 1
        }
      }

      conn_f_create =
        conn
        |> auth_conn(admin)
        |> post(~p"/api/admin/forums", forum_params)

      forum_resp = json_response(conn_f_create, 201)
      forum_id = forum_resp["forum"]["id"]
      assert forum_resp["forum"]["name"] == "Admin Forum #{unique}"

      # 5. Update Forum
      conn_f_up =
        conn
        |> auth_conn(admin)
        |> put(~p"/api/admin/forums/#{forum_id}", %{
          "forum" => %{"name" => "Renamed Forum #{unique}"}
        })

      assert json_response(conn_f_up, 200)["forum"]["name"] == "Renamed Forum #{unique}"

      # 6. Delete Forum
      conn_f_del =
        conn
        |> auth_conn(admin)
        |> delete(~p"/api/admin/forums/#{forum_id}")

      assert json_response(conn_f_del, 200)["ok"] == true

      # 7. Delete Category
      conn_cat_del =
        conn
        |> auth_conn(admin)
        |> delete(~p"/api/admin/categories/#{cat_id}")

      assert json_response(conn_cat_del, 200)["ok"] == true
    end
  end

  # =========================================================================
  # AdminUserController Tests
  # =========================================================================
  describe "AdminUserController" do
    test "list, show, update, and reset password for users", %{conn: conn} do
      admin = create_admin_user()
      target_user = create_user()

      # 1. List users
      conn_list =
        conn
        |> auth_conn(admin)
        |> get(~p"/api/admin/users?search=#{target_user.username}")

      list_resp = json_response(conn_list, 200)
      assert length(list_resp["users"]) >= 1

      # 2. Show user
      conn_show =
        conn
        |> auth_conn(admin)
        |> get(~p"/api/admin/users/#{target_user.id}")

      assert json_response(conn_show, 200)["user"]["id"] == target_user.id

      # 3. Update user
      conn_up =
        conn
        |> auth_conn(admin)
        |> put(~p"/api/admin/users/#{target_user.id}", %{
          "user" => %{"display_name" => "Admin Updated Name"}
        })

      assert json_response(conn_up, 200)["user"]["display_name"] == "Admin Updated Name"

      # 4. Reset password
      conn_reset =
        conn
        |> auth_conn(admin)
        |> post(~p"/api/admin/users/#{target_user.id}/reset-password")

      assert json_response(conn_reset, 200)["temporary_password"] != nil
    end
  end

  # =========================================================================
  # AdminGroupController Tests
  # =========================================================================
  describe "AdminGroupController" do
    test "manage groups, ranks, and memberships", %{conn: conn} do
      admin = create_admin_user()
      member = create_user()
      unique = System.unique_integer([:positive])

      # 1. Create group
      group_params = %{
        "group" => %{
          "name" => "Admin Tested Group #{unique}",
          "slug" => "admin-group-#{unique}",
          "color" => "#00FF00"
        }
      }

      conn_create_g =
        conn
        |> auth_conn(admin)
        |> post(~p"/api/admin/groups", group_params)

      group_resp = json_response(conn_create_g, 201)
      group_id = group_resp["group"]["id"]
      assert group_resp["group"]["name"] == "Admin Tested Group #{unique}"

      # 2. Update group
      conn_up_g =
        conn
        |> auth_conn(admin)
        |> put(~p"/api/admin/groups/#{group_id}", %{
          "group" => %{"name" => "Renamed Group #{unique}"}
        })

      assert json_response(conn_up_g, 200)["group"]["name"] == "Renamed Group #{unique}"

      # 3. Add member to group
      conn_add_m =
        conn
        |> auth_conn(admin)
        |> post(~p"/api/admin/groups/#{group_id}/members", %{"user_id" => member.id})

      assert json_response(conn_add_m, 200)["ok"] == true

      # 4. List group members
      conn_list_m =
        conn
        |> auth_conn(admin)
        |> get(~p"/api/admin/groups/#{group_id}/members")

      assert length(json_response(conn_list_m, 200)["members"]) >= 1

      # 5. Remove member from group
      conn_rem_m =
        conn
        |> auth_conn(admin)
        |> delete(~p"/api/admin/groups/#{group_id}/members/#{member.id}")

      assert json_response(conn_rem_m, 200)["ok"] == true

      # 6. Delete group
      conn_del_g =
        conn
        |> auth_conn(admin)
        |> delete(~p"/api/admin/groups/#{group_id}")

      assert json_response(conn_del_g, 200)["ok"] == true

      # 7. List ranks
      conn_ranks =
        conn
        |> auth_conn(admin)
        |> get(~p"/api/admin/ranks")

      assert is_list(json_response(conn_ranks, 200)["ranks"])
    end
  end

  # =========================================================================
  # AdminBBCodeController Tests
  # =========================================================================
  describe "AdminBBCodeController" do
    test "create, list, update, and delete custom bbcodes", %{conn: conn} do
      admin = create_admin_user()
      unique = System.unique_integer([:positive])

      # 1. Create BBCode
      bb_params = %{
        "bbcode" => %{
          "tag_name" => "badge_#{unique}",
          "replacement_html" => "<span class='badge'>{param}</span>",
          "description" => "Custom badge"
        }
      }

      conn_create_bb =
        conn
        |> auth_conn(admin)
        |> post(~p"/api/admin/bbcodes", bb_params)

      bb_resp = json_response(conn_create_bb, 201)
      bb_id = bb_resp["bbcode"]["id"]
      assert bb_resp["bbcode"]["tag_name"] == "badge_#{unique}"

      # 2. List BBCodes
      conn_list_bb =
        conn
        |> auth_conn(admin)
        |> get(~p"/api/admin/bbcodes")

      assert is_list(json_response(conn_list_bb, 200)["bbcodes"])

      # 3. Update BBCode
      conn_up_bb =
        conn
        |> auth_conn(admin)
        |> put(~p"/api/admin/bbcodes/#{bb_id}", %{
          "bbcode" => %{"description" => "Updated badge desc"}
        })

      assert json_response(conn_up_bb, 200)["bbcode"]["description"] == "Updated badge desc"

      # 4. Delete BBCode
      conn_del_bb =
        conn
        |> auth_conn(admin)
        |> delete(~p"/api/admin/bbcodes/#{bb_id}")

      assert json_response(conn_del_bb, 200)["ok"] == true
    end
  end

  # =========================================================================
  # AdminDashboardController Tests
  # =========================================================================
  describe "AdminDashboardController" do
    test "war-room, health-score, and audit logs", %{conn: conn} do
      admin = create_admin_user()

      # 1. War Room
      conn_war =
        conn
        |> auth_conn(admin)
        |> get(~p"/api/admin/dashboard/war-room")

      assert json_response(conn_war, 200)["stats"] != nil

      # 2. Health Score
      conn_health =
        conn
        |> auth_conn(admin)
        |> get(~p"/api/admin/dashboard/health-score")

      assert json_response(conn_health, 200)["health"] != nil

      # 3. Audit Logs
      conn_logs =
        conn
        |> auth_conn(admin)
        |> get(~p"/api/admin/audit-logs")

      assert is_list(json_response(conn_logs, 200)["logs"])
    end
  end
end
