defmodule ForgeNexusWeb.ThreadTypeControllerTest do
  use ForgeNexusWeb.ConnCase, async: false

  alias ForgeNexus.{Accounts, Forums, ThreadTypes}

  defp fresh_conn(conn) do
    b3 = rem(System.unique_integer([:positive]), 250) + 1
    b4 = rem(System.unique_integer([:positive]), 250) + 1
    %{conn | remote_ip: {10, 0, b3, b4}}
  end

  defp create_user do
    uid = System.unique_integer([:positive])

    {:ok, user} =
      Accounts.register_user(%{
        username: "tt_ctrl_u_#{uid}",
        email: "tt_ctrl_u_#{uid}@example.com",
        password: "ValidPassword123!@#"
      })

    user
  end

  defp create_thread_and_post(user) do
    uid = System.unique_integer([:positive])

    {:ok, cat} =
      Forums.create_category(%{
        name: "TT Ctrl Cat #{uid}",
        slug: "tt-ctrl-cat-#{uid}",
        position: 1
      })

    {:ok, forum} =
      Forums.create_forum(%{
        name: "TT Ctrl Forum #{uid}",
        slug: "tt-ctrl-forum-#{uid}",
        category_id: cat.id
      })

    {:ok, thread} =
      Forums.create_thread(%{
        title: "TT Ctrl Thread #{uid}",
        body: "First post content",
        forum_id: forum.id,
        user_id: user.id
      })

    {:ok, post} =
      Forums.create_post(%{
        body: "Answer post content",
        thread_id: thread.id,
        user_id: user.id
      })

    {thread, post}
  end

  describe "GET /api/thread-types" do
    test "lists all active thread types", %{conn: conn} do
      uid = System.unique_integer([:positive])

      {:ok, type} =
        ThreadTypes.create_thread_type(%{
          name: "Custom Type #{uid}",
          slug: "custom-type-#{uid}",
          label: "Custom",
          icon: "star",
          description: "A custom thread type",
          position: 5,
          is_active: true
        })

      conn = get(fresh_conn(conn), ~p"/api/thread-types")
      res = json_response(conn, 200)

      assert is_list(res["thread_types"])
      found = Enum.find(res["thread_types"], &(&1["id"] == type.id))
      assert found["name"] == type.name
      assert found["slug"] == type.slug
      assert found["label"] == "Custom"
      assert found["icon"] == "star"
      assert found["description"] == "A custom thread type"
      assert found["position"] == 5
      assert found["is_active"] == true
    end
  end

  describe "GET /api/thread-types/:slug" do
    test "returns 404 when slug does not exist", %{conn: conn} do
      conn = get(fresh_conn(conn), ~p"/api/thread-types/nonexistent-slug")
      assert json_response(conn, 404)["error"] == "thread type not found"
    end

    test "returns thread type when slug exists", %{conn: conn} do
      uid = System.unique_integer([:positive])

      {:ok, type} =
        ThreadTypes.create_thread_type(%{
          name: "Type Slug Test #{uid}",
          slug: "slug-test-#{uid}",
          label: "Slug Test",
          icon: "tag",
          description: "Slug test desc",
          position: 1,
          is_active: true
        })

      conn = get(fresh_conn(conn), ~p"/api/thread-types/#{type.slug}")
      res = json_response(conn, 200)

      assert res["thread_type"]["id"] == type.id
      assert res["thread_type"]["slug"] == type.slug
    end
  end

  describe "GET /api/threads/:thread_id/answers" do
    test "lists answers for a thread", %{conn: conn} do
      user = create_user()
      {thread, post} = create_thread_and_post(user)

      {:ok, ans} =
        ThreadTypes.create_answer(%{
          thread_id: thread.id,
          post_id: post.id
        })

      {:ok, _accepted} = ThreadTypes.accept_answer(ans, %{accepted_by_id: user.id})

      conn = get(fresh_conn(conn), ~p"/api/threads/#{thread.id}/answers")
      res = json_response(conn, 200)

      assert is_list(res["answers"])
      assert length(res["answers"]) == 1
      [ans_json] = res["answers"]
      assert ans_json["id"] == ans.id
      assert ans_json["post_id"] == post.id
      assert ans_json["is_accepted"] == true
      assert ans_json["accepted_at"] != nil
    end
  end

  describe "GET /api/threads/:thread_id/debate-positions" do
    test "returns debate positions and counts", %{conn: conn} do
      user1 = create_user()
      user2 = create_user()
      {thread, post1} = create_thread_and_post(user1)

      {:ok, post2} =
        Forums.create_post(%{body: "Debate post 2", thread_id: thread.id, user_id: user2.id})

      {:ok, _pos1} =
        ThreadTypes.set_position(%{
          thread_id: thread.id,
          post_id: post1.id,
          user_id: user1.id,
          side: "pro"
        })

      {:ok, _pos2} =
        ThreadTypes.set_position(%{
          thread_id: thread.id,
          post_id: post2.id,
          user_id: user2.id,
          side: "con"
        })

      conn = get(fresh_conn(conn), ~p"/api/threads/#{thread.id}/debate-positions")
      res = json_response(conn, 200)

      assert is_list(res["positions"])
      assert length(res["positions"]) == 2
      assert res["counts"]["pro"] == 1
      assert res["counts"]["con"] == 1

      pro_json = Enum.find(res["positions"], &(&1["position"] == "pro"))
      assert pro_json["user_id"] == user1.id
      con_json = Enum.find(res["positions"], &(&1["position"] == "con"))
      assert con_json["user_id"] == user2.id
    end

    test "handles empty positions and direct invocations", %{conn: conn} do
      user = create_user()
      {thread, _post} = create_thread_and_post(user)

      conn = get(fresh_conn(conn), ~p"/api/threads/#{thread.id}/debate-positions")
      res = json_response(conn, 200)

      assert res["positions"] == []
      assert res["counts"] == %{}
    end
  end

  describe "GET /api/threads/:thread_id/ama" do
    test "returns 404 when no AMA session exists for thread", %{conn: conn} do
      user = create_user()
      {thread, _post} = create_thread_and_post(user)

      conn = get(fresh_conn(conn), ~p"/api/threads/#{thread.id}/ama")
      assert json_response(conn, 404)["error"] == "no AMA session for thread"
    end

    test "returns AMA session details when present", %{conn: conn} do
      user = create_user()
      {thread, _post} = create_thread_and_post(user)

      {:ok, session} =
        ThreadTypes.create_ama_session(%{
          thread_id: thread.id,
          host_id: user.id,
          title: "AMA with special guest",
          status: "upcoming"
        })

      conn = get(fresh_conn(conn), ~p"/api/threads/#{thread.id}/ama")
      res = json_response(conn, 200)

      assert res["ama_session"]["id"] == session.id
      assert res["ama_session"]["thread_id"] == thread.id
      assert res["ama_session"]["host_id"] == user.id
      assert res["ama_session"]["status"] == "upcoming"
    end
  end

  describe "GET /api/threads/:thread_id/marketplace" do
    test "returns 404 when no listing exists for thread", %{conn: conn} do
      user = create_user()
      {thread, _post} = create_thread_and_post(user)

      conn = get(fresh_conn(conn), ~p"/api/threads/#{thread.id}/marketplace")
      assert json_response(conn, 404)["error"] == "no marketplace listing for thread"
    end

    test "returns marketplace listing when present", %{conn: conn} do
      user = create_user()
      {thread, _post} = create_thread_and_post(user)

      {:ok, listing} =
        ThreadTypes.create_listing(%{
          thread_id: thread.id,
          user_id: user.id,
          price: Decimal.new("120.00"),
          currency: "USD",
          condition: "good",
          status: "available",
          location: "New York",
          shipping_info: "Standard mail"
        })

      conn = get(fresh_conn(conn), ~p"/api/threads/#{thread.id}/marketplace")
      res = json_response(conn, 200)

      assert res["listing"]["id"] == listing.id
      assert res["listing"]["thread_id"] == thread.id
      assert res["listing"]["user_id"] == user.id
      assert res["listing"]["condition"] == "good"
      assert res["listing"]["status"] == "available"
      assert res["listing"]["location"] == "New York"
      assert res["listing"]["shipping_info"] == "Standard mail"
    end
  end

  describe "GET /api/threads/:thread_id/wiki-edits" do
    test "returns wiki revisions and latest content", %{conn: conn} do
      user = create_user()
      {thread, _post} = create_thread_and_post(user)

      {:ok, rev1} =
        ThreadTypes.create_wiki_edit(%{
          thread_id: thread.id,
          user_id: user.id,
          body: "Initial wiki content",
          revision_number: 1,
          edit_summary: "Initial draft"
        })

      {:ok, _rev2} =
        ThreadTypes.create_wiki_edit(%{
          thread_id: thread.id,
          user_id: user.id,
          body: "Updated wiki content with details",
          revision_number: 2,
          edit_summary: "Expanded overview"
        })

      conn = get(fresh_conn(conn), ~p"/api/threads/#{thread.id}/wiki-edits")
      res = json_response(conn, 200)

      assert is_list(res["edits"])
      assert length(res["edits"]) == 2
      assert res["latest_content"] == "Updated wiki content with details"

      rev1_json = Enum.find(res["edits"], &(&1["id"] == rev1.id))
      assert rev1_json["editor_id"] == user.id
      assert rev1_json["edit_summary"] == "Initial draft"
      assert rev1_json["revision_number"] == 1
    end

    test "returns empty wiki edits when none exist", %{conn: conn} do
      user = create_user()
      {thread, _post} = create_thread_and_post(user)

      conn = get(fresh_conn(conn), ~p"/api/threads/#{thread.id}/wiki-edits")
      res = json_response(conn, 200)

      assert res["edits"] == []
      assert res["latest_content"] == nil
    end
  end
end
