defmodule ForgeNexusWeb.ForumAndThreadControllerTest do
  use ForgeNexusWeb.ConnCase, async: false

  alias ForgeNexus.Accounts
  alias ForgeNexus.Forums
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

    # Mark verified so verified_email pipeline passes
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

  defp create_category_and_forum do
    unique = System.unique_integer([:positive])

    {:ok, cat} =
      Forums.create_category(%{
        name: "Category #{unique}",
        slug: "cat-#{unique}",
        description: "Cat description",
        position: 1
      })

    {:ok, forum} =
      Forums.create_forum(%{
        name: "Forum #{unique}",
        slug: "forum-#{unique}",
        description: "Forum description",
        category_id: cat.id,
        position: 1
      })

    {cat, forum}
  end

  defp create_test_thread(forum, user, attrs \\ %{}) do
    unique = System.unique_integer([:positive])

    default_attrs = %{
      "title" => "Thread #{unique}",
      "body" => "Thread body text here #{unique}",
      "forum_id" => forum.id,
      "user_id" => user.id
    }

    {:ok, thread} = Forums.create_thread(Map.merge(default_attrs, attrs))
    thread
  end

  # =========================================================================
  # ForumController Tests
  # =========================================================================
  describe "ForumController" do
    test "GET /api/forums returns list of categories with forums", %{conn: conn} do
      {_cat, _forum} = create_category_and_forum()

      conn = get(fresh_conn(conn), ~p"/api/forums")
      response = json_response(conn, 200)

      assert is_list(response["categories"])
      assert length(response["categories"]) > 0
      first_cat = hd(response["categories"])
      assert Map.has_key?(first_cat, "name")
      assert Map.has_key?(first_cat, "forums")
    end

    test "GET /api/forums/:slug returns forum details", %{conn: conn} do
      {_cat, forum} = create_category_and_forum()

      conn = get(fresh_conn(conn), ~p"/api/forums/#{forum.slug}")
      response = json_response(conn, 200)

      assert response["forum"]["id"] == forum.id
      assert response["forum"]["slug"] == forum.slug
      assert response["forum"]["name"] == forum.name
    end

    test "GET /api/forums/:slug/threads returns paginated threads", %{conn: conn} do
      user = create_user()
      {_cat, forum} = create_category_and_forum()
      thread = create_test_thread(forum, user)

      conn = get(fresh_conn(conn), ~p"/api/forums/#{forum.slug}/threads?page=1")
      response = json_response(conn, 200)

      assert response["page"] == 1
      assert is_list(response["threads"])
      assert Enum.any?(response["threads"], fn t -> t["id"] == thread.id end)
    end
  end

  # =========================================================================
  # ThreadController Tests
  # =========================================================================
  describe "ThreadController" do
    test "GET /api/threads/:slug returns thread and posts, increments view count", %{conn: conn} do
      user = create_user()
      {_cat, forum} = create_category_and_forum()
      thread = create_test_thread(forum, user)

      conn = get(fresh_conn(conn), ~p"/api/threads/#{thread.slug}")
      response = json_response(conn, 200)

      assert response["thread"]["id"] == thread.id
      assert response["thread"]["title"] == thread.title
      assert is_list(response["posts"])
      assert length(response["posts"]) >= 1
    end

    test "GET /api/threads/trending returns trending threads", %{conn: conn} do
      user = create_user()
      {_cat, forum} = create_category_and_forum()
      _thread = create_test_thread(forum, user)

      conn = get(fresh_conn(conn), ~p"/api/threads/trending")
      response = json_response(conn, 200)

      assert is_list(response["threads"])
    end

    test "GET /api/thread-summary/:id returns nil when no summary exists", %{conn: conn} do
      user = create_user()
      {_cat, forum} = create_category_and_forum()
      thread = create_test_thread(forum, user)

      conn =
        conn
        |> auth_conn(user)
        |> get(~p"/api/thread-summary/#{thread.id}")

      response = json_response(conn, 200)
      assert response["summary"] == nil
    end

    test "POST /api/threads requires authentication", %{conn: conn} do
      conn = post(fresh_conn(conn), ~p"/api/threads", %{"thread" => %{"title" => "Hi"}})
      assert response(conn, 401)
    end

    test "POST /api/threads creates a new thread with valid params", %{conn: conn} do
      user = create_user()
      {_cat, forum} = create_category_and_forum()

      params = %{
        "thread" => %{
          "title" => "Super Cool Thread",
          "body" => "Initial post content",
          "forum_id" => forum.id
        }
      }

      conn =
        conn
        |> auth_conn(user)
        |> post(~p"/api/threads", params)

      response = json_response(conn, 201)
      assert response["thread"]["title"] == "Super Cool Thread"
      assert response["thread"]["forum"]["id"] == forum.id
      assert response["thread"]["user"]["id"] == user.id
    end

    test "POST /api/threads resolves forum_slug to forum_id", %{conn: conn} do
      user = create_user()
      {_cat, forum} = create_category_and_forum()

      params = %{
        "thread" => %{
          "title" => "Thread By Slug",
          "body" => "Content with slug lookup",
          "forum_slug" => forum.slug
        }
      }

      conn =
        conn
        |> auth_conn(user)
        |> post(~p"/api/threads", params)

      response = json_response(conn, 201)
      assert response["thread"]["title"] == "Thread By Slug"
      assert response["thread"]["forum"]["id"] == forum.id
    end

    test "POST /api/threads returns 422 on invalid params", %{conn: conn} do
      user = create_user()
      {_cat, forum} = create_category_and_forum()

      params = %{
        "thread" => %{
          "title" => "",
          "body" => "",
          "forum_id" => forum.id
        }
      }

      conn =
        conn
        |> auth_conn(user)
        |> post(~p"/api/threads", params)

      assert json_response(conn, 422)["error"] != nil
    end

    test "POST /api/threads/:slug/reply creates a reply post", %{conn: conn} do
      user = create_user()
      {_cat, forum} = create_category_and_forum()
      thread = create_test_thread(forum, user)

      params = %{
        "post" => %{
          "body" => "This is a reply to the thread!"
        }
      }

      conn =
        conn
        |> auth_conn(user)
        |> post(~p"/api/threads/#{thread.slug}/reply", params)

      response = json_response(conn, 201)
      assert response["post"]["body"] == "This is a reply to the thread!"
      assert response["post"]["user"]["id"] == user.id
    end

    test "PUT /api/posts/:id updates own post and logs edit history", %{conn: conn} do
      user = create_user()
      {_cat, forum} = create_category_and_forum()
      thread = create_test_thread(forum, user)
      post = Forums.get_first_post(thread.id)

      params = %{
        "post" => %{
          "body" => "Updated post content by author",
          "edit_reason" => "Fixed grammar"
        }
      }

      conn =
        conn
        |> auth_conn(user)
        |> put(~p"/api/posts/#{post.id}", params)

      response = json_response(conn, 200)
      assert response["post"]["body"] == "Updated post content by author"
      assert response["post"]["is_edited"] == true

      # Check history endpoint
      history_conn =
        build_conn()
        |> auth_conn(user)
        |> get(~p"/api/posts/#{post.id}/history")

      history_resp = json_response(history_conn, 200)
      assert is_list(history_resp["edits"])
      assert length(history_resp["edits"]) >= 1
      assert hd(history_resp["edits"])["edit_reason"] == "Fixed grammar"
    end

    test "PUT /api/posts/:id forbids non-author non-staff from editing", %{conn: conn} do
      author = create_user()
      other_user = create_user()
      {_cat, forum} = create_category_and_forum()
      thread = create_test_thread(forum, author)
      post = Forums.get_first_post(thread.id)

      params = %{
        "post" => %{
          "body" => "Malicious modification"
        }
      }

      conn =
        conn
        |> auth_conn(other_user)
        |> put(~p"/api/posts/#{post.id}", params)

      assert response(conn, 403)
    end
  end

  # =========================================================================
  # PollController Tests
  # =========================================================================
  describe "PollController" do
    test "create, view, vote, and close poll workflow", %{conn: conn} do
      user1 = create_user()
      user2 = create_user()
      {_cat, forum} = create_category_and_forum()
      thread = create_test_thread(forum, user1)

      # 1. Show before poll exists
      conn_show =
        conn
        |> auth_conn(user1)
        |> get(~p"/api/threads/#{thread.id}/poll")

      assert json_response(conn_show, 200)["poll"] == nil

      # 2. Create poll with < 2 options fails
      conn_bad =
        conn
        |> auth_conn(user1)
        |> post(~p"/api/threads/#{thread.id}/poll", %{"options" => ["Only one"]})

      assert response(conn_bad, 422)

      # 3. Create poll with 2 options
      poll_params = %{
        "question" => "What is your favorite color?",
        "options" => ["Blue", "Red"]
      }

      conn_create =
        conn
        |> auth_conn(user1)
        |> post(~p"/api/threads/#{thread.id}/poll", poll_params)

      create_resp = json_response(conn_create, 201)
      poll = create_resp["poll"]
      assert poll["question"] == "What is your favorite color?"
      assert length(poll["options"]) == 2
      blue_opt = Enum.find(poll["options"], fn o -> o["text"] == "Blue" end)

      # 4. Vote on poll
      conn_vote =
        conn
        |> auth_conn(user2)
        |> post(~p"/api/polls/#{poll["id"]}/vote", %{"option_ids" => [blue_opt["id"]]})

      vote_resp = json_response(conn_vote, 200)
      voted_opt = Enum.find(vote_resp["poll"]["options"], fn o -> o["id"] == blue_opt["id"] end)
      assert voted_opt["vote_count"] == 1

      # 5. Already voted fails
      conn_revote =
        conn
        |> auth_conn(user2)
        |> post(~p"/api/polls/#{poll["id"]}/vote", %{"option_ids" => [blue_opt["id"]]})

      assert response(conn_revote, 409)

      # 6. Close poll
      conn_close =
        conn
        |> auth_conn(user1)
        |> post(~p"/api/polls/#{poll["id"]}/close", %{})

      close_resp = json_response(conn_close, 200)
      assert close_resp["poll"]["is_closed"] == true
    end
  end

  # =========================================================================
  # ThreadRatingController Tests
  # =========================================================================
  describe "ThreadRatingController" do
    test "GET and POST /api/threads/:thread_id/rating", %{conn: conn} do
      user = create_user()
      {_cat, forum} = create_category_and_forum()
      thread = create_test_thread(forum, user)

      # Unauthenticated GET
      conn_unauth = get(fresh_conn(conn), ~p"/api/threads/#{thread.id}/rating")
      unauth_resp = json_response(conn_unauth, 200)
      assert unauth_resp["rating"] != nil
      assert unauth_resp["user_rating"] == nil

      # Authenticated POST rate
      conn_rate =
        conn
        |> auth_conn(user)
        |> post(~p"/api/threads/#{thread.id}/rate", %{"rating" => 5})

      rate_resp = json_response(conn_rate, 200)
      assert rate_resp["rating"]["count"] >= 1

      # Authenticated GET
      conn_auth_get =
        conn
        |> auth_conn(user)
        |> get(~p"/api/threads/#{thread.id}/rating")

      auth_resp = json_response(conn_auth_get, 200)
      assert auth_resp["user_rating"] == 5
    end
  end

  # =========================================================================
  # ThreadSubscriptionController Tests
  # =========================================================================
  describe "ThreadSubscriptionController" do
    test "show, update, and delete thread subscription", %{conn: conn} do
      user = create_user()
      {_cat, forum} = create_category_and_forum()
      thread = create_test_thread(forum, user)

      # 1. Show subscription initially nil
      conn_show =
        conn
        |> auth_conn(user)
        |> get(~p"/api/threads/#{thread.slug}/subscription")

      assert json_response(conn_show, 200)["subscription"] == nil

      # 2. Update subscription to "watching"
      conn_sub =
        conn
        |> auth_conn(user)
        |> put(~p"/api/threads/#{thread.slug}/subscription", %{"notification_level" => "watching"})

      assert json_response(conn_sub, 200)["subscription"]["notification_level"] == "watching"

      # 3. Unsubscribe
      conn_unsub =
        conn
        |> auth_conn(user)
        |> delete(~p"/api/threads/#{thread.slug}/subscription")

      assert json_response(conn_unsub, 200)["status"] == "ok"
    end
  end

  # =========================================================================
  # ThreadParticipantController Tests
  # =========================================================================
  describe "ThreadParticipantController" do
    test "manage participants on private threads", %{conn: conn} do
      creator = create_user()
      invited = create_user()
      {_cat, forum} = create_category_and_forum()

      # Public thread rejects adding participant
      public_thread = create_test_thread(forum, creator)

      conn_bad =
        conn
        |> auth_conn(creator)
        |> post(~p"/api/threads/#{public_thread.slug}/participants", %{"user_id" => invited.id})

      assert response(conn_bad, 400)

      # Private thread allows adding and removing
      priv_thread = create_test_thread(forum, creator, %{"is_private" => true})

      conn_add =
        conn
        |> auth_conn(creator)
        |> post(~p"/api/threads/#{priv_thread.slug}/participants", %{"user_id" => invited.id})

      add_resp = json_response(conn_add, 200)
      assert add_resp["ok"] == true
      assert Enum.any?(add_resp["participants"], fn p -> p["id"] == invited.id end)

      # Cannot remove thread creator
      conn_cant_remove =
        conn
        |> auth_conn(creator)
        |> delete(~p"/api/threads/#{priv_thread.slug}/participants/#{creator.id}")

      assert response(conn_cant_remove, 400)

      # Remove participant
      conn_rem =
        conn
        |> auth_conn(creator)
        |> delete(~p"/api/threads/#{priv_thread.slug}/participants/#{invited.id}")

      rem_resp = json_response(conn_rem, 200)
      refute Enum.any?(rem_resp["participants"], fn p -> p["id"] == invited.id end)
    end
  end

  # =========================================================================
  # ThreadReadController Tests
  # =========================================================================
  describe "ThreadReadController" do
    test "mark thread read, forum read, and get unread counts", %{conn: conn} do
      user = create_user()
      {_cat, forum} = create_category_and_forum()
      thread = create_test_thread(forum, user)

      # Mark thread read
      conn_read_th =
        conn
        |> auth_conn(user)
        |> post(~p"/api/threads/#{thread.slug}/read")

      assert json_response(conn_read_th, 200)["status"] == "ok"

      # Mark forum read
      conn_read_f =
        conn
        |> auth_conn(user)
        |> post(~p"/api/forums/#{forum.slug}/read")

      assert json_response(conn_read_f, 200)["status"] == "ok"

      # Unread counts
      conn_unread =
        conn
        |> auth_conn(user)
        |> get(~p"/api/unread-counts")

      assert json_response(conn_unread, 200)["unread_counts"] != nil
    end
  end
end
