defmodule ForgeNexusWeb.EngagementAndPluginsControllerTest do
  use ForgeNexusWeb.ConnCase, async: false

  alias ForgeNexus.{
    Accounts,
    Chat,
    Guardian,
    Repo
  }

  alias ForgeNexus.Plugins.Flow
  alias ForgeNexusWeb.{PageController, SlashCommandController, VoiceRoomController}

  defp fresh_conn(conn) do
    b3 = rem(System.unique_integer([:positive]), 250) + 1
    b4 = rem(System.unique_integer([:positive]), 250) + 1
    %{conn | remote_ip: {10, 0, b3, b4}}
  end

  defp create_user(attrs \\ %{}) do
    unique = System.unique_integer([:positive])

    default_attrs = %{
      username: "eng_u_#{unique}",
      email: "eng_u_#{unique}@example.com",
      password: "ValidPassword123!@#",
      display_name: "Eng User #{unique}"
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
  # 1. FollowController
  # =========================================================================
  describe "FollowController" do
    test "toggle follow, cannot follow self, followers, following, feed", %{conn: conn} do
      user1 = create_user()
      user2 = create_user()

      # 1. Follow user2
      conn_follow =
        conn
        |> auth_conn(user1)
        |> post(~p"/api/users/#{user2.id}/follow")

      resp_f = json_response(conn_follow, 200)
      assert resp_f["following"] == true
      assert resp_f["follower_count"] >= 1

      # 2. Unfollow user2
      conn_unfollow =
        conn
        |> auth_conn(user1)
        |> post(~p"/api/users/#{user2.id}/follow")

      resp_unf = json_response(conn_unfollow, 200)
      assert resp_unf["following"] == false

      # 3. Cannot follow self -> 422
      conn_self =
        conn
        |> auth_conn(user1)
        |> post(~p"/api/users/#{user1.id}/follow")

      assert conn_self.status == 422

      # 4. Followers list
      conn_followers =
        conn
        |> auth_conn(user1)
        |> get(~p"/api/users/#{user2.id}/followers")

      assert json_response(conn_followers, 200)["users"] != nil

      # 5. Following list
      conn_following =
        conn
        |> auth_conn(user1)
        |> get(~p"/api/users/#{user1.id}/following")

      assert json_response(conn_following, 200)["users"] != nil

      # 6. Feed
      conn_feed =
        conn
        |> auth_conn(user1)
        |> get(~p"/api/following/feed")

      assert is_list(json_response(conn_feed, 200)["posts"])
    end
  end

  # =========================================================================
  # 2. SearchController
  # =========================================================================
  describe "SearchController" do
    test "GET /api/search with query validations, types, and fallback", %{conn: conn} do
      user = create_user()

      # Query too short (< 2 chars) -> 400
      conn_short = get(fresh_conn(conn), ~p"/api/search?q=a")
      assert conn_short.status == 400
      assert json_response(conn_short, 400)["error"] != nil

      # Threads search
      conn_threads = get(fresh_conn(conn), ~p"/api/search?q=elixir&type=threads")
      assert conn_threads.status == 200
      resp_t = json_response(conn_threads, 200)
      assert is_list(resp_t["results"])

      # Posts search
      conn_posts = get(fresh_conn(conn), ~p"/api/search?q=elixir&type=posts")
      assert conn_posts.status == 200
      resp_p = json_response(conn_posts, 200)
      assert is_list(resp_p["results"])

      # Author search
      conn_author = get(fresh_conn(conn), ~p"/api/search?q=elixir&author=#{user.username}")
      assert conn_author.status == 200
    end
  end

  # =========================================================================
  # 3. PageController
  # =========================================================================
  describe "PageController" do
    test "admin list, create, update, delete, and direct show", %{conn: conn} do
      admin = create_admin_user()
      unique = System.unique_integer([:positive])

      {:ok, flow} =
        %Flow{}
        |> Flow.changeset(%{
          name: "Test Flow #{unique}",
          slug: "test-flow-#{unique}",
          trigger_type: "manual",
          created_by_id: admin.id
        })
        |> Repo.insert()

      # 1. Admin list pages
      conn_list =
        conn
        |> auth_conn(admin)
        |> get(~p"/api/admin/pages")

      assert json_response(conn_list, 200)["pages"] != nil

      # 2. Admin create page
      conn_create =
        conn
        |> auth_conn(admin)
        |> post(~p"/api/admin/pages", %{
          "page" => %{
            "title" => "Custom Page #{unique}",
            "slug" => "custom-page-#{unique}",
            "description" => "Custom info page",
            "flow_id" => flow.id,
            "is_published" => true
          }
        })

      assert conn_create.status == 201
      page_id = json_response(conn_create, 201)["page"]["id"]
      page_slug = json_response(conn_create, 201)["page"]["slug"]

      # 3. Direct show (published)
      conn_show = PageController.show(fresh_conn(conn), %{"slug" => page_slug})
      assert conn_show.status == 200
      assert json_response(conn_show, 200)["page"]["slug"] == page_slug

      # 4. Direct show 404
      conn_show_404 =
        PageController.show(fresh_conn(conn), %{"slug" => "non-existent-page-slug-xyz"})

      assert conn_show_404.status == 404

      # 5. Missing page param -> 400
      conn_bad_create =
        conn
        |> auth_conn(admin)
        |> post(~p"/api/admin/pages", %{"wrong" => "data"})

      assert conn_bad_create.status == 400

      # 6. Admin update page
      conn_update =
        conn
        |> auth_conn(admin)
        |> put(~p"/api/admin/pages/#{page_id}", %{
          "page" => %{"title" => "Updated Page Title"}
        })

      assert conn_update.status == 200
      assert json_response(conn_update, 200)["page"]["title"] == "Updated Page Title"

      # 7. Update non-existent -> 404
      conn_up_404 =
        conn
        |> auth_conn(admin)
        |> put(~p"/api/admin/pages/#{Ecto.UUID.generate()}", %{
          "page" => %{"title" => "Missing"}
        })

      assert conn_up_404.status == 404

      # 8. Admin delete page
      conn_del =
        conn
        |> auth_conn(admin)
        |> delete(~p"/api/admin/pages/#{page_id}")

      assert json_response(conn_del, 200)["ok"] == true

      # 9. Delete non-existent -> 404
      conn_del_404 =
        conn
        |> auth_conn(admin)
        |> delete(~p"/api/admin/pages/#{Ecto.UUID.generate()}")

      assert conn_del_404.status == 404
    end
  end

  # =========================================================================
  # 4. SlashCommandController
  # =========================================================================
  describe "SlashCommandController" do
    test "admin CRUD, public list, and execute failure modes", %{conn: conn} do
      admin = create_admin_user()
      unique = System.unique_integer([:positive])
      cmd_name = "roll_#{unique}"

      # 1. Admin list
      conn_list =
        conn
        |> auth_conn(admin)
        |> get(~p"/api/admin/commands")

      assert json_response(conn_list, 200)["commands"] != nil

      # 2. Admin create command
      conn_create =
        conn
        |> auth_conn(admin)
        |> post(~p"/api/admin/commands", %{
          "command" => %{
            "name" => cmd_name,
            "description" => "Roll a die",
            "category" => "general",
            "permission_level" => "everyone",
            "response_type" => "channel",
            "enabled" => true
          }
        })

      assert conn_create.status == 201
      cmd_id = json_response(conn_create, 201)["command"]["id"]

      # 3. Create invalid command (bad name) -> 422
      conn_invalid =
        conn
        |> auth_conn(admin)
        |> post(~p"/api/admin/commands", %{
          "command" => %{
            "name" => "INVALID NAME!",
            "description" => "Bad"
          }
        })

      assert conn_invalid.status == 422

      # 4. Admin update command
      conn_update =
        conn
        |> auth_conn(admin)
        |> put(~p"/api/admin/commands/#{cmd_id}", %{
          "command" => %{"description" => "Updated roll description"}
        })

      assert conn_update.status == 200

      assert json_response(conn_update, 200)["command"]["description"] ==
               "Updated roll description"

      # 5. Public list
      conn_pub = SlashCommandController.list(fresh_conn(conn), %{})
      assert conn_pub.status == 200
      assert json_response(conn_pub, 200)["categories"] != nil

      # 6. Execute unknown command -> 404
      conn_exec_unknown =
        conn
        |> auth_conn(admin)
        |> post(~p"/api/commands/execute", %{"command" => "non_existent_cmd_xyz"})

      assert conn_exec_unknown.status == 404

      # 7. Admin delete command
      conn_del =
        conn
        |> auth_conn(admin)
        |> delete(~p"/api/admin/commands/#{cmd_id}")

      assert json_response(conn_del, 200)["ok"] == true
    end
  end

  # =========================================================================
  # 5. CallController
  # =========================================================================
  describe "CallController" do
    test "initiate, active, answer, hang_up, and history", %{conn: conn} do
      user1 = create_user()
      user2 = create_user()

      {:ok, conversation} = Chat.get_or_create_direct_conversation(user1.id, user2.id)

      # 1. Initiate call
      conn_init =
        conn
        |> auth_conn(user1)
        |> post(~p"/api/calls", %{
          "conversation_id" => conversation.id,
          "type" => "audio"
        })

      assert conn_init.status == 201
      call = json_response(conn_init, 201)["call"]
      call_id = call["id"]
      assert call["status"] == "ringing"

      # 2. Get active call
      conn_active =
        conn
        |> auth_conn(user1)
        |> get(~p"/api/conversations/#{conversation.id}/calls/active")

      assert json_response(conn_active, 200)["call"]["id"] == call_id

      # 3. Answer call (by user2)
      conn_answer =
        conn
        |> auth_conn(user2)
        |> post(~p"/api/calls/#{call_id}/answer")

      assert conn_answer.status == 200
      assert json_response(conn_answer, 200)["call"]["status"] == "active"

      # 4. Hang up
      conn_hang =
        conn
        |> auth_conn(user1)
        |> post(~p"/api/calls/#{call_id}/hang-up")

      assert conn_hang.status == 200
      assert json_response(conn_hang, 200)["call"]["status"] == "ended"

      # 5. Call history
      conn_hist =
        conn
        |> auth_conn(user1)
        |> get(~p"/api/conversations/#{conversation.id}/calls/history")

      assert length(json_response(conn_hist, 200)["calls"]) >= 1
    end
  end

  # =========================================================================
  # 6. VoiceRoomController
  # =========================================================================
  describe "VoiceRoomController" do
    test "lifecycle: index, upcoming, show, create, update, delete, and ice_config", %{conn: conn} do
      admin = create_admin_user()
      authed = auth_conn(conn, admin)
      unique = System.unique_integer([:positive])

      # 1. Create room
      conn_create =
        VoiceRoomController.create(authed, %{
          "name" => "Gaming Lounge #{unique}",
          "type" => "lounge",
          "max_participants" => 25
        })

      assert conn_create.status == 201
      room_id = json_response(conn_create, 201)["room"]["id"]
      room_slug = json_response(conn_create, 201)["room"]["slug"]

      # 2. Index
      conn_index = VoiceRoomController.index(authed, %{})
      assert conn_index.status == 200
      assert Enum.any?(json_response(conn_index, 200)["rooms"], &(&1["id"] == room_id))

      # 3. Upcoming
      conn_up = VoiceRoomController.upcoming(authed, %{})
      assert conn_up.status == 200

      # 4. Show room
      conn_show = VoiceRoomController.show(authed, %{"slug" => room_slug})
      assert conn_show.status == 200
      assert json_response(conn_show, 200)["room"]["slug"] == room_slug

      # 5. Show non-existent room -> 404
      conn_show_404 =
        VoiceRoomController.show(authed, %{"slug" => "non-existent-room-slug-xyz"})

      assert conn_show_404.status == 404

      # 6. Update room
      conn_update =
        VoiceRoomController.update(authed, %{
          "id" => room_id,
          "name" => "Updated Gaming Lounge #{unique}"
        })

      assert conn_update.status == 200

      # 7. ICE config
      conn_ice = VoiceRoomController.ice_config(authed, %{})
      assert conn_ice.status == 200
      assert json_response(conn_ice, 200)["ice_servers"] != nil

      # 8. Create validation error
      conn_create_err = VoiceRoomController.create(authed, %{"name" => ""})
      assert conn_create_err.status == 422

      # 9. Delete room
      conn_del = VoiceRoomController.delete(authed, %{"id" => room_id})
      assert json_response(conn_del, 200)["ok"] == true
    end
  end
end
