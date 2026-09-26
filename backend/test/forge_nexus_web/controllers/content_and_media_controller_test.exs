defmodule ForgeNexusWeb.ContentAndMediaControllerTest do
  use ForgeNexusWeb.ConnCase, async: false

  alias ForgeNexus.{
    Accounts,
    AI,
    Channels,
    Communities,
    Forums,
    Guardian,
    Repo
  }

  alias ForgeNexusWeb.{
    ActivityController,
    ActivityHeatmapController,
    AIController,
    GalleryController
  }

  defp fresh_conn(conn) do
    b3 = rem(System.unique_integer([:positive]), 250) + 1
    b4 = rem(System.unique_integer([:positive]), 250) + 1
    %{conn | remote_ip: {10, 0, b3, b4}}
  end

  defp create_user(attrs \\ %{}) do
    unique = System.unique_integer([:positive])

    default_attrs = %{
      username: "cm_u_#{unique}",
      email: "cm_u_#{unique}@example.com",
      password: "ValidPassword123!@#",
      display_name: "CM User #{unique}"
    }

    {:ok, user} = Accounts.register_user(Map.merge(default_attrs, attrs))

    now = DateTime.utc_now() |> DateTime.truncate(:second)
    {:ok, verified} = user |> Ecto.Changeset.change(email_verified_at: now) |> Repo.update()
    verified
  end

  defp create_community(user) do
    unique = System.unique_integer([:positive])

    {:ok, community} =
      Communities.create_community(%{
        name: "Test Comm #{unique}",
        slug: "test-comm-#{unique}",
        owner_id: user.id
      })

    community
  end

  defp auth_conn(conn, user, community \\ nil) do
    {:ok, token, _claims} = Guardian.encode_and_sign(user)

    conn =
      conn
      |> fresh_conn()
      |> Guardian.Plug.put_current_resource(user)
      |> Guardian.Plug.put_current_token(token)
      |> put_req_header("authorization", "Bearer #{token}")
      |> put_req_cookie("fn_token", token)

    if community do
      assign(conn, :community_id, community.id)
    else
      conn
    end
  end

  defp create_forum_thread_post(user) do
    unique = System.unique_integer([:positive])

    {:ok, cat} =
      Forums.create_category(%{
        name: "CM Category #{unique}",
        slug: "cm-cat-#{unique}",
        position: 1
      })

    {:ok, forum} =
      Forums.create_forum(%{
        name: "CM Forum #{unique}",
        slug: "cm-forum-#{unique}",
        category_id: cat.id
      })

    {:ok, thread} =
      Forums.create_thread(%{
        title: "CM Thread #{unique}",
        body: "First post body in CM thread",
        forum_id: forum.id,
        user_id: user.id
      })

    post = Repo.get_by!(Forums.Post, thread_id: thread.id)
    {forum, thread, post}
  end

  # =========================================================================
  # 1. AchievementController
  # =========================================================================
  describe "AchievementController" do
    test "GET /api/achievements and /api/users/:user_id/achievements", %{conn: conn} do
      user = create_user()

      conn_all = get(fresh_conn(conn), ~p"/api/achievements")
      assert json_response(conn_all, 200)["achievements"] != nil

      conn_user = get(fresh_conn(conn), ~p"/api/users/#{user.id}/achievements")
      assert is_list(json_response(conn_user, 200)["achievements"])
    end
  end

  # =========================================================================
  # 2. AIController
  # =========================================================================
  describe "AIController" do
    test "tag_suggestions, translate, and thread_summary", %{conn: conn} do
      user = create_user()
      {_forum, thread, post} = create_forum_thread_post(user)

      # 1. Tag suggestions (when none exist)
      conn_sugg_empty =
        get(fresh_conn(conn), ~p"/api/threads/#{thread.id}/tag-suggestions")

      assert json_response(conn_sugg_empty, 200)["suggestions"] == []

      # Create tag suggestion
      {:ok, _sugg} =
        AI.create_tag_suggestion(%{
          thread_id: thread.id,
          suggested_tags: ["elixir", "phoenix"]
        })

      conn_sugg = get(fresh_conn(conn), ~p"/api/threads/#{thread.id}/tag-suggestions")
      assert length(json_response(conn_sugg, 200)["suggestions"]) == 1

      # 2. Translation (404 when none exist)
      conn_trans_empty = get(fresh_conn(conn), ~p"/api/posts/#{post.id}/translate?lang=es")
      assert conn_trans_empty.status == 404

      # Create translation
      {:ok, _trans} =
        AI.create_translation(%{
          post_id: post.id,
          source_language: "en",
          target_language: "es",
          translated_body: "Hola mundo"
        })

      # Translation lookup (note: translated_text fallback to translated_body if mapped)
      conn_trans = get(fresh_conn(conn), ~p"/api/posts/#{post.id}/translate?lang=es")
      assert conn_trans.status == 200

      # 3. Direct thread_summary
      conn_ts_none =
        AIController.thread_summary(fresh_conn(conn), %{"thread_id" => thread.id})

      assert conn_ts_none.status == 404

      {:ok, _ts} =
        AI.upsert_thread_summary(thread.id, %{
          summary: "Summary of thread",
          key_points: ["point 1"],
          post_count_at_generation: 1
        })

      conn_ts_ok =
        AIController.thread_summary(fresh_conn(conn), %{"thread_id" => thread.id})

      assert conn_ts_ok.status == 200
      assert json_response(conn_ts_ok, 200)["summary"]["summary"] == "Summary of thread"
    end
  end

  # =========================================================================
  # 3. ActivityController & ActivityHeatmapController
  # =========================================================================
  describe "ActivityController & ActivityHeatmapController" do
    test "ActivityController.show and ActivityHeatmapController.show", %{conn: conn} do
      user = create_user()
      _other = create_user()
      {_forum, _thread, _post} = create_forum_thread_post(user)

      authed = auth_conn(conn, user)

      # Activity show
      conn_act = ActivityController.show(authed, %{"slug" => user.slug})
      assert conn_act.status == 200
      assert json_response(conn_act, 200)["activity"]["posts"] != nil

      # Activity 404 for missing slug
      conn_act_404 = ActivityController.show(authed, %{"slug" => "non-existent-user-xyz"})
      assert conn_act_404.status == 404

      # Activity heatmap show
      conn_heat = ActivityHeatmapController.show(fresh_conn(conn), %{"slug" => user.slug})
      assert conn_heat.status == 200
      assert json_response(conn_heat, 200)["heatmap"] != nil

      # Heatmap 404
      conn_heat_404 =
        ActivityHeatmapController.show(fresh_conn(conn), %{"slug" => "non-existent-user-xyz"})

      assert conn_heat_404.status == 404
    end
  end

  # =========================================================================
  # 4. ApiKeyController
  # =========================================================================
  describe "ApiKeyController" do
    test "index, create, usage, and revoke", %{conn: conn} do
      user = create_user()
      community = create_community(user)

      authed = auth_conn(conn, user, community)

      # 1. Create API key
      conn_create =
        post(authed, ~p"/api/api-keys", %{"name" => "Integration Key", "plan" => "free"})

      assert conn_create.status == 201
      resp_k = json_response(conn_create, 201)
      key_id = resp_k["api_key"]["id"]
      assert resp_k["secret"] != nil

      # 2. List API keys
      conn_list = get(authed, ~p"/api/api-keys")
      assert Enum.any?(json_response(conn_list, 200)["api_keys"], &(&1["id"] == key_id))

      # 3. Usage
      conn_usage = get(authed, ~p"/api/api-keys/#{key_id}/usage")
      assert json_response(conn_usage, 200)["totals"] != nil

      # Usage 404
      conn_u_404 = get(authed, ~p"/api/api-keys/#{Ecto.UUID.generate()}/usage")
      assert conn_u_404.status == 404

      # 4. Revoke
      conn_rev = delete(authed, ~p"/api/api-keys/#{key_id}")
      assert json_response(conn_rev, 200)["ok"] == true

      # Revoke 404
      conn_r_404 = delete(authed, ~p"/api/api-keys/#{Ecto.UUID.generate()}")
      assert conn_r_404.status == 404
    end
  end

  # =========================================================================
  # 5. BookmarkController
  # =========================================================================
  describe "BookmarkController" do
    test "index, toggle, and bookmark_ids", %{conn: conn} do
      user = create_user()
      authed = auth_conn(conn, user)

      # Create channel and message to bookmark
      {:ok, channel} =
        Channels.create_channel(%{
          name: "bookmark-chan-#{System.unique_integer([:positive])}",
          type: "text"
        })

      {:ok, message} =
        Channels.create_message(channel.id, user.id, %{body: "Message to bookmark"})

      # 1. Bookmark IDs initially
      conn_ids_init = get(authed, ~p"/api/bookmarks/ids")
      assert json_response(conn_ids_init, 200)["message_ids"] == []

      # 2. Toggle bookmark on
      conn_tog_on =
        post(authed, ~p"/api/bookmarks", %{
          "message_id" => message.id,
          "note" => "Remember this"
        })

      assert json_response(conn_tog_on, 200)["bookmarked"] == true

      # 3. Index
      conn_idx = get(authed, ~p"/api/bookmarks")
      assert length(json_response(conn_idx, 200)["bookmarks"]) >= 1

      # 4. Bookmark IDs includes message.id
      conn_ids = get(authed, ~p"/api/bookmarks/ids")
      assert Enum.member?(json_response(conn_ids, 200)["message_ids"], message.id)

      # 5. Toggle bookmark off
      conn_tog_off = post(authed, ~p"/api/bookmarks", %{"message_id" => message.id})
      assert json_response(conn_tog_off, 200)["bookmarked"] == false
    end
  end

  # =========================================================================
  # 6. ContentIgnoreController
  # =========================================================================
  describe "ContentIgnoreController" do
    test "ignore and unignore forum and thread", %{conn: conn} do
      user = create_user()
      {forum, thread, _post} = create_forum_thread_post(user)
      authed = auth_conn(conn, user)

      # 1. Ignore forum
      conn_ign_f = post(authed, ~p"/api/ignores/forum/#{forum.id}")
      assert json_response(conn_ign_f, 200)["status"] == "ok"

      # 2. Ignore thread
      conn_ign_t = post(authed, ~p"/api/ignores/thread/#{thread.id}")
      assert json_response(conn_ign_t, 200)["status"] == "ok"

      # 3. Index
      conn_idx = get(authed, ~p"/api/ignores")
      assert length(json_response(conn_idx, 200)["ignores"]) >= 2

      # 4. Unignore thread
      conn_unign_t = delete(authed, ~p"/api/ignores/thread/#{thread.id}")
      assert json_response(conn_unign_t, 200)["status"] == "ok"

      # 5. Unignore forum
      conn_unign_f = delete(authed, ~p"/api/ignores/forum/#{forum.id}")
      assert json_response(conn_unign_f, 200)["status"] == "ok"

      # 6. Unignore non-muted returns 404
      conn_unign_404 = delete(authed, ~p"/api/ignores/forum/#{forum.id}")
      assert conn_unign_404.status == 404
    end
  end

  # =========================================================================
  # 7. FeedController
  # =========================================================================
  describe "FeedController" do
    test "status post, like, comment, poke, presence, and premium", %{conn: conn} do
      user1 = create_user()
      user2 = create_user()
      community = create_community(user1)

      authed1 = auth_conn(conn, user1, community)
      authed2 = auth_conn(conn, user2, community)

      # 1. Create status post
      conn_status =
        post(authed1, ~p"/api/feed/status", %{
          "body" => "Hello status feed!"
        })

      assert conn_status.status == 201
      post_id = json_response(conn_status, 201)["post"]["id"]

      # 2. Like status post
      conn_like = post(authed2, ~p"/api/feed/#{post_id}/like")
      assert json_response(conn_like, 200)["action"] != nil

      # 3. Comment on status post
      conn_comment =
        post(authed2, ~p"/api/feed/#{post_id}/comment", %{
          "body" => "Nice status post!"
        })

      assert conn_comment.status == 201

      # 4. Send poke
      conn_poke =
        post(authed1, ~p"/api/poke", %{
          "to_user_id" => user2.id,
          "type" => "wave",
          "message" => "Hey there!"
        })

      assert json_response(conn_poke, 200)["ok"] == true

      # 5. List pokes
      conn_pokes = get(authed2, ~p"/api/pokes")
      assert json_response(conn_pokes, 200)["unread_count"] >= 1

      # 6. Mark pokes read
      conn_read = post(authed2, ~p"/api/pokes/read")
      assert json_response(conn_read, 200)["ok"] == true

      # 7. Update presence
      conn_pres =
        put(authed1, ~p"/api/presence", %{
          "status" => "online",
          "activity" => "Coding"
        })

      assert json_response(conn_pres, 200)["ok"] == true

      # 8. Premium status
      conn_prem = get(authed1, ~p"/api/premium")
      assert json_response(conn_prem, 200)["is_premium"] == false
    end
  end

  # =========================================================================
  # 8. GalleryController
  # =========================================================================
  describe "GalleryController" do
    test "recent, user_albums, show, and direct actions (create, update, delete, add_media, remove_media)",
         %{conn: conn} do
      user = create_user()
      authed = auth_conn(conn, user)
      unique = System.unique_integer([:positive])

      # 1. Create album
      conn_create =
        GalleryController.create(authed, %{
          "title" => "Summer Fest #{unique}",
          "description" => "Event photos",
          "is_public" => true
        })

      assert conn_create.status == 201
      album_id = json_response(conn_create, 201)["album"]["id"]

      # 2. Public show
      conn_show = get(fresh_conn(conn), ~p"/api/gallery/albums/#{album_id}")
      assert json_response(conn_show, 200)["album"]["id"] == album_id

      # 3. User albums
      conn_user_alb = get(fresh_conn(conn), ~p"/api/gallery/user/#{user.id}")
      assert is_list(json_response(conn_user_alb, 200)["albums"])

      # 4. Recent
      conn_recent = get(fresh_conn(conn), ~p"/api/gallery/recent")
      assert is_list(json_response(conn_recent, 200)["items"])

      # 5. My albums
      conn_my = GalleryController.my_albums(authed, %{})
      assert conn_my.status == 200

      # 6. Update album
      conn_up =
        GalleryController.update(authed, %{
          "id" => album_id,
          "description" => "Updated album description"
        })

      assert conn_up.status == 200

      # 7. Add media
      conn_add_m =
        GalleryController.add_media(authed, %{
          "album_id" => album_id,
          "file_url" => "https://example.com/photo.png",
          "file_type" => "image",
          "file_size" => 1024,
          "caption" => "Sunset"
        })

      assert conn_add_m.status == 201
      media_id = json_response(conn_add_m, 201)["item"]["id"]

      # 8. Remove media
      conn_rm_m = GalleryController.remove_media(authed, %{"id" => media_id})
      assert json_response(conn_rm_m, 200)["ok"] == true

      # 9. Delete album
      conn_del = GalleryController.delete(authed, %{"id" => album_id})
      assert json_response(conn_del, 200)["ok"] == true
    end
  end

  # =========================================================================
  # 9. MarketplaceController
  # =========================================================================
  describe "MarketplaceController" do
    test "list_templates, show_template, list_plugins, and show_plugin", %{conn: conn} do
      # 1. List templates
      conn_temp = get(fresh_conn(conn), ~p"/api/marketplace/templates")
      assert json_response(conn_temp, 200)["templates"] != nil

      # 2. Show template 404
      conn_temp_404 =
        get(fresh_conn(conn), ~p"/api/marketplace/templates/#{Ecto.UUID.generate()}")

      assert conn_temp_404.status == 404

      # 3. List plugins
      conn_plug = get(fresh_conn(conn), ~p"/api/marketplace/plugins")
      assert json_response(conn_plug, 200)["plugins"] != nil

      # 4. Show plugin 404
      conn_plug_404 =
        get(fresh_conn(conn), ~p"/api/marketplace/plugins/#{Ecto.UUID.generate()}")

      assert conn_plug_404.status == 404
    end
  end

  # =========================================================================
  # 10. RssController & SitemapController
  # =========================================================================
  describe "RssController & SitemapController" do
    test "GET /api/rss/threads, /api/rss/posts, and /api/sitemap.xml", %{conn: conn} do
      user = create_user()
      {_forum, _thread, _post} = create_forum_thread_post(user)

      # 1. RSS threads
      conn_rss_t = get(fresh_conn(conn), ~p"/api/rss/threads")
      assert conn_rss_t.status == 200
      assert response_content_type(conn_rss_t, :xml) =~ "xml"
      assert conn_rss_t.resp_body =~ "<rss"

      # 2. RSS posts
      conn_rss_p = get(fresh_conn(conn), ~p"/api/rss/posts")
      assert conn_rss_p.status == 200
      assert response_content_type(conn_rss_p, :xml) =~ "xml"
      assert conn_rss_p.resp_body =~ "<rss"

      # 3. Sitemap
      conn_sitemap = get(fresh_conn(conn), ~p"/api/sitemap.xml")
      assert conn_sitemap.status == 200
      assert response_content_type(conn_sitemap, :xml) =~ "xml"
      assert conn_sitemap.resp_body =~ "<urlset"
    end
  end
end
