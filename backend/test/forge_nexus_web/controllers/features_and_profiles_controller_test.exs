defmodule ForgeNexusWeb.FeaturesAndProfilesControllerTest do
  use ForgeNexusWeb.ConnCase, async: false

  alias ForgeNexus.{
    Accounts,
    Forums,
    Guardian,
    Repo,
    Voice
  }

  alias ForgeNexusWeb.{
    FeaturesController,
    OverlayController,
    ProfileController
  }

  defp fresh_conn(conn) do
    b3 = rem(System.unique_integer([:positive]), 250) + 1
    b4 = rem(System.unique_integer([:positive]), 250) + 1
    %{conn | remote_ip: {10, 0, b3, b4}}
  end

  defp create_user(attrs \\ %{}) do
    unique = System.unique_integer([:positive])

    default_attrs = %{
      username: "fp_u_#{unique}",
      email: "fp_u_#{unique}@example.com",
      password: "ValidPassword123!@#",
      display_name: "FP User #{unique}"
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

  defp create_forum_and_thread(user) do
    unique = System.unique_integer([:positive])

    {:ok, cat} =
      Forums.create_category(%{
        name: "FP Category #{unique}",
        position: 1
      })

    {:ok, forum} =
      Forums.create_forum(%{
        name: "FP Forum #{unique}",
        slug: "fp-forum-#{unique}",
        category_id: cat.id,
        position: 1
      })

    {:ok, thread} =
      Forums.create_thread(%{
        title: "FP Thread #{unique}",
        body: "Initial thread post content",
        forum_id: forum.id,
        user_id: user.id
      })

    {forum, thread}
  end

  # =========================================================================
  # 1. FeaturesController
  # =========================================================================
  describe "FeaturesController" do
    test "BBCode, ratings, solved, prefixes, blocks, drafts, similar, bookmarks, reactions", %{
      conn: conn
    } do
      user1 = create_user()
      user2 = create_user()
      authed1 = auth_conn(conn, user1)
      authed2 = auth_conn(conn, user2)

      {forum, thread} = create_forum_and_thread(user1)

      {:ok, reply_post} =
        Forums.create_post(%{thread_id: thread.id, user_id: user2.id, body: "Here is an answer"})

      # 1. BBCode render
      conn_bb = post(authed1, ~p"/api/bbcode/render", %{"body" => "[b]Bold[/b]"})
      assert conn_bb.status == 200
      assert json_response(conn_bb, 200)["html"] =~ "<strong>Bold</strong>"

      conn_bb_empty = post(authed1, ~p"/api/bbcode/render", %{})
      assert conn_bb_empty.status == 200
      assert json_response(conn_bb_empty, 200)["html"] == ""

      # 2. Post ratings
      conn_rate =
        post(authed2, ~p"/api/posts/#{reply_post.id}/rate", %{"rating_type" => "helpful"})

      assert conn_rate.status in [200, 422]

      conn_ratings = get(authed2, ~p"/api/posts/#{reply_post.id}/ratings")
      assert conn_ratings.status == 200
      assert is_list(json_response(conn_ratings, 200)["ratings"])

      # 3. Solved / Unmark Solved
      conn_sol =
        post(authed1, ~p"/api/threads/#{thread.id}/mark-solved", %{
          "thread_id" => thread.id,
          "post_id" => reply_post.id
        })

      assert conn_sol.status in [200, 422]

      conn_unsol = delete(authed1, ~p"/api/threads/#{thread.id}/mark-solved")
      assert conn_unsol.status in [200, 422]

      # Unauthorized user marking solved
      conn_sol_unauth =
        post(authed2, ~p"/api/threads/#{thread.id}/mark-solved", %{
          "thread_id" => thread.id,
          "post_id" => reply_post.id
        })

      assert conn_sol_unauth.status == 403

      # 4. Prefixes
      conn_pref_list = get(authed1, ~p"/api/forums/#{forum.id}/prefixes")
      assert conn_pref_list.status == 200
      assert is_list(json_response(conn_pref_list, 200)["prefixes"])

      # Admin prefixes and CRUD
      {:ok, prefix} =
        Forums.create_prefix(%{
          name: "Guide",
          color: "#FFFFFF",
          bg_color: "#0000FF",
          forum_id: forum.id,
          is_global: false
        })

      conn_set_pref =
        post(authed1, ~p"/api/threads/#{thread.id}/prefix", %{
          "thread_id" => thread.id,
          "prefix_id" => prefix.id
        })

      assert conn_set_pref.status == 200
      assert json_response(conn_set_pref, 200)["ok"] == true

      # Direct controller calls for admin prefixes
      conn_admin_pref = FeaturesController.admin_list_prefixes(authed1, %{})
      assert conn_admin_pref.status == 200

      conn_pref_create =
        FeaturesController.create_prefix(authed1, %{
          name: "Solved",
          color: "#00FF00",
          bg_color: "#000000"
        })

      assert conn_pref_create.status == 201
      p_id = json_response(conn_pref_create, 201)["prefix"]["id"]

      conn_pref_upd =
        FeaturesController.update_prefix(authed1, %{"id" => p_id, "name" => "Closed"})

      assert conn_pref_upd.status == 200

      conn_pref_del = FeaturesController.delete_prefix(authed1, %{"id" => p_id})
      assert conn_pref_del.status == 200

      # 5. User Blocks
      conn_block = post(authed1, ~p"/api/users/#{user2.id}/block")
      assert conn_block.status == 200
      assert json_response(conn_block, 200)["ok"] == true

      conn_list_block = get(authed1, ~p"/api/blocked-users")
      assert conn_list_block.status == 200
      assert Enum.any?(json_response(conn_list_block, 200)["blocked"], &(&1["id"] == user2.id))

      conn_unblock = delete(authed1, ~p"/api/users/#{user2.id}/block")
      assert conn_unblock.status == 200
      assert json_response(conn_unblock, 200)["ok"] == true

      # 6. Drafts
      conn_draft_save =
        post(authed1, ~p"/api/drafts", %{
          "context_type" => "thread_create",
          "context_id" => forum.id,
          "title" => "Draft Thread",
          "body" => "Work in progress"
        })

      assert conn_draft_save.status == 200
      assert json_response(conn_draft_save, 200)["draft"]["title"] == "Draft Thread"

      conn_draft_get = get(authed1, ~p"/api/drafts/thread_create/#{forum.id}")
      assert conn_draft_get.status == 200
      assert json_response(conn_draft_get, 200)["draft"]["title"] == "Draft Thread"

      conn_draft_del = delete(authed1, ~p"/api/drafts/thread_create/#{forum.id}")
      assert conn_draft_del.status == 200
      assert json_response(conn_draft_del, 200)["ok"] == true

      # 7. Similar Threads
      conn_sim = get(fresh_conn(conn), ~p"/api/threads/similar", %{"title" => "FP Thread"})
      assert conn_sim.status == 200
      assert is_list(json_response(conn_sim, 200)["threads"])

      # 8. Post Bookmarks
      conn_bm_ids = get(authed1, ~p"/api/post-bookmarks/ids")
      assert conn_bm_ids.status == 200
      assert is_list(json_response(conn_bm_ids, 200)["post_ids"])

      conn_bm_tog =
        post(authed1, ~p"/api/posts/#{reply_post.id}/bookmark", %{
          "post_id" => reply_post.id,
          "note" => "Good answer"
        })

      assert conn_bm_tog.status == 200
      assert json_response(conn_bm_tog, 200)["bookmarked"] == true

      conn_bm_list = get(authed1, ~p"/api/post-bookmarks")
      assert conn_bm_list.status == 200
      assert length(json_response(conn_bm_list, 200)["bookmarks"]) >= 1

      # 9. Post Reactions
      conn_react =
        post(authed1, ~p"/api/posts/#{reply_post.id}/react", %{
          "post_id" => reply_post.id,
          "reaction" => "like"
        })

      assert conn_react.status == 200
      assert is_map(json_response(conn_react, 200)["counts"])

      conn_reactions = get(authed1, ~p"/api/posts/#{reply_post.id}/reactions")
      assert conn_reactions.status == 200
      assert is_map(json_response(conn_reactions, 200)["counts"])
    end
  end

  # =========================================================================
  # 2. ForgeCodeController
  # =========================================================================
  describe "ForgeCodeController" do
    test "vocabulary, gallery, mine, create, show, update, apply, delete", %{conn: conn} do
      user = create_user()
      authed = auth_conn(conn, user)
      unique = System.unique_integer([:positive])

      # 1. Vocabulary
      conn_voc = get(fresh_conn(conn), ~p"/api/forge-codes/vocabulary")
      assert conn_voc.status == 200
      voc = json_response(conn_voc, 200)
      assert Map.has_key?(voc, "fonts")
      assert Map.has_key?(voc, "vibes")

      # 2. Gallery
      conn_gal = get(fresh_conn(conn), ~p"/api/forge-codes/gallery?tab=featured")
      assert conn_gal.status == 200
      assert is_list(json_response(conn_gal, 200)["codes"])

      # 3. Mine initially
      conn_mine_init = get(authed, ~p"/api/forge-codes-mine")
      assert conn_mine_init.status == 200
      assert json_response(conn_mine_init, 200)["codes"] == []

      # 4. Create Forge Code
      conn_create =
        post(authed, ~p"/api/forge-codes", %{
          "name" => "Retro Neon #{unique}",
          "description" => "A sleek retro theme",
          "vibe_tag" => "retro",
          "is_public" => true,
          "is_remixable" => true
        })

      assert conn_create.status == 201
      code = json_response(conn_create, 201)["code"]["code"]

      # Error branch on create (missing name)
      conn_create_err = post(authed, ~p"/api/forge-codes", %{})
      assert conn_create_err.status == 400

      # 5. Show
      conn_show = get(fresh_conn(conn), ~p"/api/forge-codes/#{code}")
      assert conn_show.status == 200
      assert json_response(conn_show, 200)["code"]["code"] == code

      # Show nonexistent
      conn_show_nf = get(fresh_conn(conn), ~p"/api/forge-codes/nonexistent-code-123")
      assert conn_show_nf.status == 404

      # 6. Apply
      conn_apply = post(authed, ~p"/api/forge-codes/#{code}/apply")
      assert conn_apply.status == 200
      assert json_response(conn_apply, 200)["ok"] == true

      # 7. Update
      conn_upd =
        put(authed, ~p"/api/forge-codes/#{code}", %{
          "description" => "Updated description"
        })

      assert conn_upd.status == 200
      assert json_response(conn_upd, 200)["code"]["description"] == "Updated description"

      # 8. Delete
      conn_del = delete(authed, ~p"/api/forge-codes/#{code}")
      assert conn_del.status == 200
      assert json_response(conn_del, 200)["ok"] == true
    end
  end

  # =========================================================================
  # 3. ProfileController & ProfileEndorsementController
  # =========================================================================
  describe "ProfileController & ProfileEndorsementController" do
    test "profile show, blurbs, mood, layout, css, widgets, guestbook, reputation, frames", %{
      conn: conn
    } do
      user1 = create_user()
      user2 = create_user()
      authed1 = auth_conn(conn, user1)
      authed2 = auth_conn(conn, user2)

      # 1. Show profile
      conn_show = get(authed2, ~p"/api/profiles/#{user1.slug}")
      assert conn_show.status == 200
      assert json_response(conn_show, 200)["profile"]["id"] == user1.id

      # 2. Avatar frames
      conn_frames = get(authed1, ~p"/api/avatar-frames")
      assert conn_frames.status == 200
      assert is_list(json_response(conn_frames, 200)["frames"])

      # 3. Update main profile & partials
      conn_upd_prof =
        put(authed1, ~p"/api/profile", %{
          "profile" => %{
            "bio" => "Hello world bio",
            "location" => "Earth"
          }
        })

      assert conn_upd_prof.status == 200
      assert json_response(conn_upd_prof, 200)["profile"]["bio"] == "Hello world bio"

      # Partial updates: blurbs, mood, layout, css
      conn_blurbs =
        put(authed1, ~p"/api/profile/blurbs", %{
          "interests" => "Coding, gaming",
          "heroes" => "Ada Lovelace"
        })

      assert conn_blurbs.status == 200
      assert json_response(conn_blurbs, 200)["profile"]["interests"] == "Coding, gaming"

      conn_mood =
        put(authed1, ~p"/api/profile/mood", %{
          "profile_mood" => "Energetic",
          "profile_mood_emoji" => "⚡"
        })

      assert conn_mood.status == 200
      assert json_response(conn_mood, 200)["profile"]["profile_mood"] == "Energetic"

      conn_layout =
        put(authed1, ~p"/api/profile/layout", %{
          "profile_layout" => "classic"
        })

      assert conn_layout.status == 200
      assert json_response(conn_layout, 200)["profile"]["profile_layout"] == "classic"

      conn_css =
        put(authed1, ~p"/api/profile/css", %{
          "profile_accent_color" => "#6366F1"
        })

      assert conn_css.status == 200
      assert json_response(conn_css, 200)["profile"]["profile_accent_color"] == "#6366F1"

      # 4. Top friends
      conn_tf = put(authed1, ~p"/api/profile/top-friends", %{"friend_ids" => [user2.id]})
      assert conn_tf.status == 200
      assert Enum.any?(json_response(conn_tf, 200)["top_friends"], &(&1["id"] == user2.id))

      # 5. Widgets CRUD
      conn_w_create =
        post(authed1, ~p"/api/profile/widgets", %{
          "type" => "custom_html",
          "title" => "About My Page",
          "config" => %{"text" => "Welcome to my space"},
          "position" => 1,
          "is_visible" => true
        })

      assert conn_w_create.status == 201
      widget_id = json_response(conn_w_create, 201)["widget"]["id"]

      conn_w_list = get(authed1, ~p"/api/profile/widgets")
      assert conn_w_list.status == 200
      assert Enum.any?(json_response(conn_w_list, 200)["widgets"], &(&1["id"] == widget_id))

      conn_w_upd =
        put(authed1, ~p"/api/profile/widgets/#{widget_id}", %{
          "title" => "Updated Widget Title"
        })

      assert conn_w_upd.status == 200
      assert json_response(conn_w_upd, 200)["widget"]["title"] == "Updated Widget Title"

      conn_w_del = delete(authed1, ~p"/api/profile/widgets/#{widget_id}")
      assert conn_w_del.status == 200
      assert json_response(conn_w_del, 200)["ok"] == true

      # 6. Guestbook
      conn_gb_sign =
        ProfileController.sign_guestbook(authed2, %{
          "slug" => user1.slug,
          "body" => "Thanks for the add!"
        })

      assert conn_gb_sign.status == 201
      entry_id = json_response(conn_gb_sign, 201)["entry"]["id"]

      conn_gb_list = get(fresh_conn(conn), ~p"/api/profiles/#{user1.slug}/guestbook")
      assert conn_gb_list.status == 200
      assert Enum.any?(json_response(conn_gb_list, 200)["guestbook"], &(&1["id"] == entry_id))

      conn_gb_del = ProfileController.delete_guestbook_entry(authed1, %{"id" => entry_id})
      assert conn_gb_del.status == 200
      assert json_response(conn_gb_del, 200)["ok"] == true

      # 7. Reputation
      conn_rep_get = get(fresh_conn(conn), ~p"/api/profiles/#{user1.slug}/reputation")
      assert conn_rep_get.status == 200
      assert is_list(json_response(conn_rep_get, 200)["breakdown"])

      conn_rep_give =
        post(authed2, ~p"/api/reputation", %{
          "user_id" => user1.id,
          "amount" => 5,
          "reason" => "Great help"
        })

      assert conn_rep_give.status == 200
      assert json_response(conn_rep_give, 200)["success"] == true

      # Self-reputation error
      conn_rep_self =
        post(authed1, ~p"/api/reputation", %{
          "user_id" => user1.id,
          "amount" => 5
        })

      assert conn_rep_self.status == 422

      # 8. Profile Endorsements
      conn_endorse =
        post(authed2, ~p"/api/profiles/#{user1.slug}/endorse", %{"emoji" => "🔥"})

      assert conn_endorse.status in [201, 422]

      conn_endorse_del =
        delete(authed2, ~p"/api/profiles/#{user1.slug}/endorse", %{"emoji" => "🔥"})

      assert conn_endorse_del.status in [200, 404]

      # 9. Pin and Unpin thread
      {_forum, thread} = create_forum_and_thread(user1)
      conn_pin = put(authed1, ~p"/api/profile/pin-thread", %{"thread_id" => thread.id})
      assert conn_pin.status == 200
      assert json_response(conn_pin, 200)["ok"] == true

      conn_unpin = delete(authed1, ~p"/api/profile/pin-thread")
      assert conn_unpin.status == 200
      assert json_response(conn_unpin, 200)["ok"] == true

      # 10. Analytics
      conn_ana = get(authed1, ~p"/api/profile/analytics")
      assert conn_ana.status == 200
      assert Map.has_key?(json_response(conn_ana, 200), "daily")

      # 11. AI Summary
      conn_ai = post(authed1, ~p"/api/profiles/#{user1.slug}/ai-summary")
      assert conn_ai.status in [200, 503, 502]
    end
  end

  # =========================================================================
  # 4. UserPreferenceController
  # =========================================================================
  describe "UserPreferenceController" do
    test "show and update preferences", %{conn: conn} do
      user = create_user()
      authed = auth_conn(conn, user)

      # 1. Show
      conn_show = get(authed, ~p"/api/user/preferences")
      assert conn_show.status == 200
      assert is_map(json_response(conn_show, 200)["preferences"])

      # 2. Update
      conn_upd =
        put(authed, ~p"/api/user/preferences", %{
          "preferences" => %{
            "show_signatures" => false,
            "posts_per_page" => 50,
            "reduced_motion" => true
          }
        })

      assert conn_upd.status == 200
      prefs = json_response(conn_upd, 200)["preferences"]
      assert prefs["show_signatures"] == false
      assert prefs["posts_per_page"] == 50
      assert prefs["reduced_motion"] == true
    end
  end

  # =========================================================================
  # 5. MemberController
  # =========================================================================
  describe "MemberController" do
    test "index, search_users, and recent_posts", %{conn: conn} do
      user = create_user()
      {_forum, _thread} = create_forum_and_thread(user)

      # 1. Index
      conn_idx = get(fresh_conn(conn), ~p"/api/members", %{"page" => "1", "sort" => "posts"})
      assert conn_idx.status == 200
      assert is_list(json_response(conn_idx, 200)["members"])

      # 2. Search users
      conn_search = get(fresh_conn(conn), ~p"/api/members/search", %{"q" => user.username})
      assert conn_search.status == 200
      assert Enum.any?(json_response(conn_search, 200)["users"], &(&1["id"] == user.id))

      # 3. Recent posts
      conn_recent = get(fresh_conn(conn), ~p"/api/recent-posts")
      assert conn_recent.status == 200
      assert is_list(json_response(conn_recent, 200)["posts"])
    end
  end

  # =========================================================================
  # 6. FederationController
  # =========================================================================
  describe "FederationController" do
    test "actor, inbox, outbox, and webfinger", %{conn: conn} do
      # 1. Actor (nonexistent returns 404)
      conn_actor = get(fresh_conn(conn), ~p"/api/ap/actors/unknown-actor-id")
      assert conn_actor.status == 404

      # 2. Inbox (minimal accept)
      conn_inbox = post(fresh_conn(conn), ~p"/api/ap/actors/some-actor/inbox", %{})
      assert conn_inbox.status == 202
      assert json_response(conn_inbox, 202)["ok"] == true

      # 3. Outbox (nonexistent returns 404)
      conn_outbox = get(fresh_conn(conn), ~p"/api/ap/actors/unknown-actor-id/outbox")
      assert conn_outbox.status == 404

      # 4. Webfinger valid
      conn_wf =
        get(fresh_conn(conn), ~p"/.well-known/webfinger", %{
          "resource" => "acct:alice@example.com"
        })

      assert conn_wf.status == 200
      assert json_response(conn_wf, 200)["subject"] == "acct:alice@example.com"

      # 5. Webfinger invalid
      conn_wf_inv =
        get(fresh_conn(conn), ~p"/.well-known/webfinger", %{"resource" => "invalid-format"})

      assert conn_wf_inv.status == 400
    end
  end

  # =========================================================================
  # 7. OverlayController
  # =========================================================================
  describe "OverlayController" do
    test "generate_token and show HTML overlay", %{conn: conn} do
      admin = create_admin_user()
      authed_admin = auth_conn(conn, admin)

      {:ok, room} = Voice.create_room(%{name: "Gaming Lounge", created_by_id: admin.id})

      # 1. Generate token
      conn_gen = post(authed_admin, ~p"/api/admin/voice/rooms/#{room.id}/overlay-token")
      assert conn_gen.status == 200
      token = json_response(conn_gen, 200)["token"]
      assert is_binary(token)

      # 2. Show overlays
      for type <- ["chat", "alerts", "events", "goals", "now", "full"] do
        conn_show = get(fresh_conn(conn), ~p"/overlay/#{token}/#{type}")
        assert conn_show.status == 200
        assert response_content_type(conn_show, :html) =~ "text/html"
        assert response(conn_show, 200) =~ room.name
      end

      # 3. Invalid token
      conn_inv =
        OverlayController.show(fresh_conn(conn), %{"token" => "invalid_token", "type" => "chat"})

      assert conn_inv.status == 404
    end
  end

  # =========================================================================
  # 8. Affiliate, CreatorDashboard, and CommunityStats Controllers
  # =========================================================================
  describe "Affiliate, CreatorDashboard, and CommunityStats Controllers" do
    test "affiliate progress and enable", %{conn: conn} do
      user = create_user()
      authed = auth_conn(conn, user)

      # 1. Progress
      conn_prog = get(authed, ~p"/api/creator/affiliate-progress")
      assert conn_prog.status == 200
      assert Map.has_key?(json_response(conn_prog, 200), "progress")

      # 2. Enable
      conn_en = post(authed, ~p"/api/creator/enable-subscriptions")
      assert conn_en.status in [200, 403]
    end

    test "creator dashboard show", %{conn: conn} do
      user = create_user()
      authed = auth_conn(conn, user)

      conn_dash = get(authed, ~p"/api/creator/dashboard", %{"days" => "14"})
      assert conn_dash.status == 200
      assert Map.has_key?(json_response(conn_dash, 200), "dashboard")
    end

    test "community stats index, contributors, and popular topics", %{conn: conn} do
      conn_idx = get(fresh_conn(conn), ~p"/api/stats/community", %{"days" => "7"})
      assert conn_idx.status == 200
      assert is_list(json_response(conn_idx, 200)["daily"])

      conn_contrib = get(fresh_conn(conn), ~p"/api/stats/community/contributors")
      assert conn_contrib.status == 200
      assert is_list(json_response(conn_contrib, 200)["contributors"])

      conn_topics = get(fresh_conn(conn), ~p"/api/stats/community/topics")
      assert conn_topics.status == 200
      assert is_list(json_response(conn_topics, 200)["topics"])
    end
  end
end
