defmodule ForgeNexusWeb.SocialAndEconomyControllerTest do
  use ForgeNexusWeb.ConnCase, async: false

  alias ForgeNexus.Accounts
  alias ForgeNexus.Forums
  alias ForgeNexus.Economy
  alias ForgeNexus.Guardian

  defp fresh_conn(conn) do
    b3 = rem(System.unique_integer([:positive]), 250) + 1
    b4 = rem(System.unique_integer([:positive]), 250) + 1
    %{conn | remote_ip: {10, 0, b3, b4}}
  end

  defp create_user(attrs \\ %{}) do
    unique = System.unique_integer([:positive])

    default_attrs = %{
      username: "soc_user_#{unique}",
      email: "soc_user_#{unique}@example.com",
      password: "Fn9#xK8$mQ2!wZ7^vL4*",
      display_name: "Soc User #{unique}"
    }

    {:ok, user} = Accounts.register_user(Map.merge(default_attrs, attrs))

    now = DateTime.utc_now() |> DateTime.truncate(:second)

    {:ok, verified} =
      user |> Ecto.Changeset.change(email_verified_at: now) |> ForgeNexus.Repo.update()

    verified
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
        name: "Soc Cat #{unique}",
        slug: "soc-cat-#{unique}",
        position: 1
      })

    {:ok, forum} =
      Forums.create_forum(%{
        name: "Soc Forum #{unique}",
        slug: "soc-forum-#{unique}",
        category_id: cat.id,
        position: 1
      })

    {:ok, thread} =
      Forums.create_thread(%{
        "title" => "Soc Thread #{unique}",
        "body" => "Soc Thread Body #{unique}",
        "forum_id" => forum.id,
        "user_id" => user.id
      })

    post = Forums.get_first_post(thread.id)
    {forum, thread, post}
  end

  # =========================================================================
  # EconomyController Tests
  # =========================================================================
  describe "EconomyController" do
    test "balance, history, leaderboard, and tipping", %{conn: conn} do
      alice = create_user()
      bob = create_user()

      # Give alice points
      {:ok, _} =
        Economy.award_points(alice.id, "initial_grant", amount: 100, description: "Welcome bonus")

      # 1. Balance
      conn_bal =
        conn
        |> auth_conn(alice)
        |> get(~p"/api/economy/balance")

      assert json_response(conn_bal, 200)["points"] == 100

      # 2. History
      conn_hist =
        conn
        |> auth_conn(alice)
        |> get(~p"/api/economy/history")

      hist_resp = json_response(conn_hist, 200)
      assert is_list(hist_resp["transactions"])
      assert length(hist_resp["transactions"]) >= 1

      # 3. Leaderboard
      conn_lead = get(fresh_conn(conn), ~p"/api/points/leaderboard")
      lead_resp = json_response(conn_lead, 200)
      assert is_list(lead_resp["leaderboard"])

      # 4. Tipping self fails
      conn_self_tip =
        conn
        |> auth_conn(alice)
        |> post(~p"/api/economy/tip", %{"to_user_id" => alice.id, "amount" => 10})

      assert response(conn_self_tip, 400)

      # 5. Tipping more than balance fails
      conn_over_tip =
        conn
        |> auth_conn(alice)
        |> post(~p"/api/economy/tip", %{"to_user_id" => bob.id, "amount" => 500})

      assert response(conn_over_tip, 422)

      # 6. Valid tip
      conn_valid_tip =
        conn
        |> auth_conn(alice)
        |> post(~p"/api/economy/tip", %{
          "to_user_id" => bob.id,
          "amount" => 25,
          "message" => "Great work!"
        })

      assert json_response(conn_valid_tip, 200)["ok"] == true
      assert Economy.get_points(alice.id) == 75
      assert Economy.get_points(bob.id) == 25
    end
  end

  # =========================================================================
  # FeaturesController Tests
  # =========================================================================
  describe "FeaturesController" do
    test "BBCode render", %{conn: conn} do
      user = create_user()

      conn_bb =
        conn
        |> auth_conn(user)
        |> post(~p"/api/bbcode/render", %{"body" => "[b]Bold Text[/b]"})

      resp = json_response(conn_bb, 200)
      assert resp["html"] =~ "<strong>Bold Text</strong>"
    end

    test "post ratings (likes) and post reactions (emoji)", %{conn: conn} do
      author = create_user()
      rater = create_user()
      {_forum, _thread, post} = create_forum_and_thread(author)

      # Self rating fails with 422
      conn_self_rate =
        conn
        |> auth_conn(author)
        |> post(~p"/api/posts/#{post.id}/rate", %{"rating_type" => "like"})

      assert response(conn_self_rate, 422)

      # Self reaction fails with 422
      conn_self_react =
        conn
        |> auth_conn(author)
        |> post(~p"/api/posts/#{post.id}/react", %{"reaction" => "like"})

      assert response(conn_self_react, 422)

      # 1. Other user rates post
      conn_rate =
        conn
        |> auth_conn(rater)
        |> post(~p"/api/posts/#{post.id}/rate", %{"rating_type" => "like"})

      rate_resp = json_response(conn_rate, 200)
      assert rate_resp["ratings"] != nil

      # Get ratings
      conn_get_rates =
        conn
        |> auth_conn(rater)
        |> get(~p"/api/posts/#{post.id}/ratings")

      assert is_list(json_response(conn_get_rates, 200)["ratings"])

      # 2. React to post with valid enum ("like")
      conn_react =
        conn
        |> auth_conn(rater)
        |> post(~p"/api/posts/#{post.id}/react", %{"reaction" => "like"})

      react_resp = json_response(conn_react, 200)
      assert react_resp["counts"] != nil

      # Get reactions
      conn_get_reacts =
        conn
        |> auth_conn(rater)
        |> get(~p"/api/posts/#{post.id}/reactions")

      assert is_list(json_response(conn_get_reacts, 200)["my_reactions"])
    end

    test "post bookmarks toggle, list, and ids", %{conn: conn} do
      user = create_user()
      {_forum, _thread, post} = create_forum_and_thread(user)

      # Toggle bookmark on
      conn_toggle1 =
        conn
        |> auth_conn(user)
        |> post(~p"/api/posts/#{post.id}/bookmark")

      assert json_response(conn_toggle1, 200)["bookmarked"] == true

      # Get bookmark IDs
      conn_ids =
        conn
        |> auth_conn(user)
        |> get(~p"/api/post-bookmarks/ids")

      assert post.id in json_response(conn_ids, 200)["post_ids"]

      # List bookmarks
      conn_list =
        conn
        |> auth_conn(user)
        |> get(~p"/api/post-bookmarks")

      list_resp = json_response(conn_list, 200)
      assert is_list(list_resp["bookmarks"])
      assert length(list_resp["bookmarks"]) >= 1

      # Toggle bookmark off
      conn_toggle2 =
        conn
        |> auth_conn(user)
        |> post(~p"/api/posts/#{post.id}/bookmark")

      assert json_response(conn_toggle2, 200)["bookmarked"] == false
    end

    test "draft autosave, get, and delete", %{conn: conn} do
      user = create_user()

      draft_params = %{
        "context_type" => "thread_create",
        "context_id" => "new",
        "title" => "Draft Title",
        "body" => "Draft Content Here"
      }

      # 1. Save draft
      conn_save =
        conn
        |> auth_conn(user)
        |> post(~p"/api/drafts", draft_params)

      assert json_response(conn_save, 200)["draft"] != nil

      # 2. Get draft
      conn_get =
        conn
        |> auth_conn(user)
        |> get(~p"/api/drafts/thread_create/new")

      get_resp = json_response(conn_get, 200)
      assert get_resp["draft"]["title"] == "Draft Title"

      # 3. Delete draft
      conn_del =
        conn
        |> auth_conn(user)
        |> delete(~p"/api/drafts/thread_create/new")

      assert json_response(conn_del, 200)["ok"] == true
    end

    test "block and unblock users", %{conn: conn} do
      user = create_user()
      target = create_user()

      # Block
      conn_block =
        conn
        |> auth_conn(user)
        |> post(~p"/api/users/#{target.id}/block")

      assert json_response(conn_block, 200)["ok"] == true

      # List blocked
      conn_list =
        conn
        |> auth_conn(user)
        |> get(~p"/api/blocked-users")

      blocked_users = json_response(conn_list, 200)["blocked"]
      assert Enum.any?(blocked_users, fn u -> u["id"] == target.id end)

      # Unblock
      conn_unblock =
        conn
        |> auth_conn(user)
        |> delete(~p"/api/users/#{target.id}/block")

      assert json_response(conn_unblock, 200)["ok"] == true
    end

    test "mark thread solved and unmark solved", %{conn: conn} do
      user = create_user()
      {_forum, thread, post} = create_forum_and_thread(user)

      # Mark solved
      conn_solve =
        conn
        |> auth_conn(user)
        |> post(~p"/api/threads/#{thread.id}/mark-solved", %{"post_id" => post.id})

      assert json_response(conn_solve, 200)["ok"] == true

      # Unmark solved
      conn_unsolve =
        conn
        |> auth_conn(user)
        |> delete(~p"/api/threads/#{thread.id}/mark-solved")

      assert json_response(conn_unsolve, 200)["ok"] == true
    end
  end

  # =========================================================================
  # StatsController Tests
  # =========================================================================
  describe "StatsController" do
    test "public stats endpoints return valid JSON", %{conn: conn} do
      # 1. /api/stats
      conn_stats = get(fresh_conn(conn), ~p"/api/stats")
      assert json_response(conn_stats, 200)["stats"] != nil

      # 2. /api/stats/cached
      conn_cached = get(fresh_conn(conn), ~p"/api/stats/cached")
      assert json_response(conn_cached, 200)["stats"] != nil

      # 3. /api/users/online
      conn_online = get(fresh_conn(conn), ~p"/api/users/online")
      assert json_response(conn_online, 200)["users"] != nil

      # 4. /api/featured-threads
      conn_feat = get(fresh_conn(conn), ~p"/api/featured-threads")
      assert is_list(json_response(conn_feat, 200)["threads"])

      # 5. /api/stats/welcome
      conn_welc = get(fresh_conn(conn), ~p"/api/stats/welcome")
      assert json_response(conn_welc, 200)["welcome"] != nil
    end
  end

  # =========================================================================
  # NotificationController Tests
  # =========================================================================
  describe "NotificationController" do
    test "index, count, and mark_all_read", %{conn: conn} do
      user = create_user()

      # Unread count
      conn_count =
        conn
        |> auth_conn(user)
        |> get(~p"/api/notifications/count")

      assert json_response(conn_count, 200)["count"] >= 0

      # List notifications
      conn_list =
        conn
        |> auth_conn(user)
        |> get(~p"/api/notifications")

      assert is_list(json_response(conn_list, 200)["notifications"])

      # Mark all read
      conn_read_all =
        conn
        |> auth_conn(user)
        |> put(~p"/api/notifications/read-all")

      assert json_response(conn_read_all, 200)["ok"] == true
    end
  end

  # =========================================================================
  # FollowController Tests
  # =========================================================================
  describe "FollowController" do
    test "follow, unfollow, cannot follow self, and list followers/following", %{conn: conn} do
      alice = create_user()
      bob = create_user()

      # Cannot follow self
      conn_self =
        conn
        |> auth_conn(alice)
        |> post(~p"/api/users/#{alice.id}/follow")

      assert response(conn_self, 422)

      # Follow bob
      conn_fol =
        conn
        |> auth_conn(alice)
        |> post(~p"/api/users/#{bob.id}/follow")

      fol_resp = json_response(conn_fol, 200)
      assert fol_resp["following"] == true
      assert fol_resp["follower_count"] >= 1

      # Followers of bob
      conn_followers =
        conn
        |> auth_conn(alice)
        |> get(~p"/api/users/#{bob.id}/followers")

      followers_resp = json_response(conn_followers, 200)
      assert Enum.any?(followers_resp["users"], fn u -> u["id"] == alice.id end)

      # Following of alice
      conn_following =
        conn
        |> auth_conn(alice)
        |> get(~p"/api/users/#{alice.id}/following")

      following_resp = json_response(conn_following, 200)
      assert Enum.any?(following_resp["users"], fn u -> u["id"] == bob.id end)

      # Unfollow bob
      conn_unfol =
        conn
        |> auth_conn(alice)
        |> post(~p"/api/users/#{bob.id}/follow")

      unfol_resp = json_response(conn_unfol, 200)
      assert unfol_resp["following"] == false
    end
  end
end
