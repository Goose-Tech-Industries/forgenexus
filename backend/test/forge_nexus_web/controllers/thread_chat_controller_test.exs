defmodule ForgeNexusWeb.ThreadChatControllerTest do
  use ForgeNexusWeb.ConnCase, async: false

  alias ForgeNexus.Accounts
  alias ForgeNexus.Accounts.UserGroup
  alias ForgeNexus.Channels
  alias ForgeNexus.Channels.ChatThread
  alias ForgeNexus.Channels.ThreadMessage
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
      username: "thread_user_#{unique}",
      email: "thread_user_#{unique}@example.com",
      password: "Fn9#xK8$mQ2!wZ7^vL4*",
      display_name: "Thread User #{unique}"
    }

    {:ok, user} = Accounts.register_user(Map.merge(default_attrs, attrs))

    now = DateTime.utc_now() |> DateTime.truncate(:second)
    {:ok, verified} = user |> Ecto.Changeset.change(email_verified_at: now) |> Repo.update()
    verified
  end

  defp auth_conn(conn, user) do
    {:ok, token, _claims} = Guardian.encode_and_sign(user)

    conn
    |> fresh_conn()
    |> put_req_header("authorization", "Bearer #{token}")
    |> put_req_cookie("fn_token", token)
  end

  defp create_channel(attrs \\ %{}) do
    unique = System.unique_integer([:positive])

    {:ok, cat} =
      Channels.create_category(%{
        name: "Thread Cat #{unique}",
        slug: "thread-cat-#{unique}",
        position: 1
      })

    default_attrs = %{
      name: "Thread Channel #{unique}",
      slug: "thread-ch-#{unique}",
      category_id: cat.id,
      topic: "Threading Discussion",
      position: 1
    }

    {:ok, ch} = Channels.create_channel(Map.merge(default_attrs, attrs))
    {cat, ch}
  end

  describe "POST /api/channels/:channel_slug/messages/:message_id/threads" do
    test "returns 404 when channel does not exist", %{conn: conn} do
      user = create_user()
      fake_msg_id = Ecto.UUID.generate()

      conn =
        conn
        |> auth_conn(user)
        |> post(~p"/api/channels/nonexistent-channel/messages/#{fake_msg_id}/threads", %{
          "name" => "My Thread"
        })

      assert json_response(conn, 404)["error"] == "Channel not found"
    end

    test "returns 403 when user cannot post in channel", %{conn: conn} do
      user = create_user()
      {_cat, ch} = create_channel(%{is_read_only: true})
      fake_msg_id = Ecto.UUID.generate()

      conn =
        conn
        |> auth_conn(user)
        |> post(~p"/api/channels/#{ch.slug}/messages/#{fake_msg_id}/threads", %{
          "name" => "Forbidden Thread"
        })

      assert json_response(conn, 403)["error"] == "Cannot create threads here"
    end

    test "returns 422 when thread creation fails validation", %{conn: conn} do
      user = create_user()
      {_cat, ch} = create_channel()
      {:ok, parent_msg} = Channels.create_message(ch.id, user.id, %{body: "Parent message"})

      conn =
        conn
        |> auth_conn(user)
        |> post(~p"/api/channels/#{ch.slug}/messages/#{parent_msg.id}/threads", %{
          "name" => ""
        })

      assert json_response(conn, 422)["error"] == "Failed to create thread"
    end

    test "successfully creates thread with creator info", %{conn: conn} do
      user = create_user()
      {_cat, ch} = create_channel()
      {:ok, parent_msg} = Channels.create_message(ch.id, user.id, %{body: "Parent message"})

      conn =
        conn
        |> auth_conn(user)
        |> post(~p"/api/channels/#{ch.slug}/messages/#{parent_msg.id}/threads", %{
          "name" => "Great Discussion"
        })

      res = json_response(conn, 201)
      assert %{"thread" => thread} = res
      assert thread["name"] == "Great Discussion"
      assert thread["channel_id"] == ch.id
      assert thread["parent_message_id"] == parent_msg.id
      assert thread["created_by"]["id"] == user.id
      assert thread["created_by"]["username"] == user.username
    end
  end

  describe "GET /api/channels/:channel_slug/threads" do
    test "returns 404 when channel does not exist", %{conn: conn} do
      user = create_user()

      conn =
        conn
        |> auth_conn(user)
        |> get(~p"/api/channels/nonexistent-channel/threads")

      assert json_response(conn, 404)["error"] == "Channel not found"
    end

    test "lists threads for valid channel including thread without creator", %{conn: conn} do
      user = create_user()
      {_cat, ch} = create_channel()
      {:ok, parent_msg} = Channels.create_message(ch.id, user.id, %{body: "Parent message 1"})
      {:ok, thread} = Channels.create_thread(ch.id, parent_msg.id, user.id, "Thread 1")

      # Allow created_by_id to be null inside sandbox to test created_by == nil branch
      Repo.query!("ALTER TABLE chat_threads ALTER COLUMN created_by_id DROP NOT NULL")
      {:ok, parent_msg2} = Channels.create_message(ch.id, user.id, %{body: "Parent message 2"})

      orphan =
        %ChatThread{
          name: "Orphan Thread",
          channel_id: ch.id,
          parent_message_id: parent_msg2.id,
          created_by_id: nil
        }
        |> Repo.insert!()

      conn =
        conn
        |> auth_conn(user)
        |> get(~p"/api/channels/#{ch.slug}/threads")

      res = json_response(conn, 200)
      assert is_list(res["threads"])
      assert Enum.any?(res["threads"], fn t -> t["id"] == thread.id && t["created_by"] != nil end)
      assert Enum.any?(res["threads"], fn t -> t["id"] == orphan.id && t["created_by"] == nil end)
    end
  end

  describe "GET /api/chat-threads/:id" do
    test "returns 404 when thread does not exist", %{conn: conn} do
      user = create_user()
      fake_id = Ecto.UUID.generate()

      conn =
        conn
        |> auth_conn(user)
        |> get(~p"/api/chat-threads/#{fake_id}")

      assert json_response(conn, 404)["error"] == "Thread not found"
    end

    test "returns thread details and messages", %{conn: conn} do
      user = create_user()
      {_cat, ch} = create_channel()
      {:ok, parent_msg} = Channels.create_message(ch.id, user.id, %{body: "Parent message"})
      {:ok, thread} = Channels.create_thread(ch.id, parent_msg.id, user.id, "Thread 1")
      {:ok, msg} = Channels.create_thread_message(thread.id, user.id, "Hello in thread")

      conn =
        conn
        |> auth_conn(user)
        |> get(~p"/api/chat-threads/#{thread.id}")

      res = json_response(conn, 200)
      assert res["thread"]["id"] == thread.id
      assert is_list(res["messages"])
      assert Enum.any?(res["messages"], fn m -> m["id"] == msg.id end)
    end
  end

  describe "GET /api/chat-threads/:id/messages" do
    test "supports pagination and limit options", %{conn: conn} do
      user = create_user()
      {_cat, ch} = create_channel()
      {:ok, parent_msg} = Channels.create_message(ch.id, user.id, %{body: "Parent message"})
      {:ok, thread} = Channels.create_thread(ch.id, parent_msg.id, user.id, "Thread 1")
      {:ok, msg1} = Channels.create_thread_message(thread.id, user.id, "Msg 1")
      {:ok, _msg2} = Channels.create_thread_message(thread.id, user.id, "Msg 2")

      # 1. No params
      conn1 =
        conn
        |> auth_conn(user)
        |> get(~p"/api/chat-threads/#{thread.id}/messages")

      assert length(json_response(conn1, 200)["messages"]) == 2

      # 2. Before parameter
      conn2 =
        conn
        |> auth_conn(user)
        |> get(~p"/api/chat-threads/#{thread.id}/messages?before=#{msg1.id}")

      assert is_list(json_response(conn2, 200)["messages"])

      # 3. Limit as valid binary string
      conn3 =
        conn
        |> auth_conn(user)
        |> get(~p"/api/chat-threads/#{thread.id}/messages?limit=1")

      assert length(json_response(conn3, 200)["messages"]) == 1

      # 4. Limit as invalid binary string
      conn4 =
        conn
        |> auth_conn(user)
        |> get(~p"/api/chat-threads/#{thread.id}/messages?limit=not_an_int")

      assert length(json_response(conn4, 200)["messages"]) == 2

      # 5. Direct call to messages with integer limit and fallback non-binary limit
      conn_direct1 =
        ForgeNexusWeb.ThreadChatController.messages(
          auth_conn(conn, user),
          %{"id" => thread.id, "limit" => 1}
        )

      assert length(json_response(conn_direct1, 200)["messages"]) == 1

      conn_direct2 =
        ForgeNexusWeb.ThreadChatController.messages(
          auth_conn(conn, user),
          %{"id" => thread.id, "limit" => :other_type}
        )

      assert length(json_response(conn_direct2, 200)["messages"]) == 2
    end
  end

  describe "POST /api/chat-threads/:id/messages" do
    test "returns 404 when thread does not exist", %{conn: conn} do
      user = create_user()
      fake_id = Ecto.UUID.generate()

      conn =
        conn
        |> auth_conn(user)
        |> post(~p"/api/chat-threads/#{fake_id}/messages", %{"body" => "Hello"})

      assert json_response(conn, 404)["error"] == "Thread not found"
    end

    test "returns 403 when thread is locked", %{conn: conn} do
      user = create_user()
      {_cat, ch} = create_channel()
      {:ok, parent_msg} = Channels.create_message(ch.id, user.id, %{body: "Parent message"})
      {:ok, thread} = Channels.create_thread(ch.id, parent_msg.id, user.id, "Thread 1")
      {:ok, _} = Channels.lock_thread_chat(thread.id)

      conn =
        conn
        |> auth_conn(user)
        |> post(~p"/api/chat-threads/#{thread.id}/messages", %{"body" => "Hello"})

      assert json_response(conn, 403)["error"] == "Thread is locked"
    end

    test "returns 403 when thread is archived", %{conn: conn} do
      user = create_user()
      {_cat, ch} = create_channel()
      {:ok, parent_msg} = Channels.create_message(ch.id, user.id, %{body: "Parent message"})
      {:ok, thread} = Channels.create_thread(ch.id, parent_msg.id, user.id, "Thread 1")
      {:ok, _} = Channels.archive_thread(thread.id)

      conn =
        conn
        |> auth_conn(user)
        |> post(~p"/api/chat-threads/#{thread.id}/messages", %{"body" => "Hello"})

      assert json_response(conn, 403)["error"] == "Thread is archived"
    end

    test "returns 422 when message creation fails validation", %{conn: conn} do
      user = create_user()
      {_cat, ch} = create_channel()
      {:ok, parent_msg} = Channels.create_message(ch.id, user.id, %{body: "Parent message"})
      {:ok, thread} = Channels.create_thread(ch.id, parent_msg.id, user.id, "Thread 1")

      conn =
        conn
        |> auth_conn(user)
        |> post(~p"/api/chat-threads/#{thread.id}/messages", %{"body" => ""})

      assert json_response(conn, 422)["error"] == "Failed to send message"
    end

    test "creates message and broadcasts to PubSub topic", %{conn: conn} do
      user = create_user()
      {_cat, ch} = create_channel()
      {:ok, parent_msg} = Channels.create_message(ch.id, user.id, %{body: "Parent message"})
      {:ok, thread} = Channels.create_thread(ch.id, parent_msg.id, user.id, "Thread 1")

      ForgeNexusWeb.Endpoint.subscribe("thread:#{thread.id}")

      conn =
        conn
        |> auth_conn(user)
        |> post(~p"/api/chat-threads/#{thread.id}/messages", %{"body" => "New thread reply!"})

      res = json_response(conn, 201)
      assert res["message"]["body"] == "New thread reply!"

      assert_receive %Phoenix.Socket.Broadcast{
        topic: topic,
        event: "new_message",
        payload: payload
      }

      assert topic == "thread:#{thread.id}"
      assert payload.body == "New thread reply!"
    end
  end

  describe "user styles and fallback serialization" do
    test "covers username_color, username_effect, group fallbacks, and nil user", %{conn: conn} do
      # 1. Group with username_color and username_effect
      unique = System.unique_integer([:positive])

      {:ok, group1} =
        %UserGroup{}
        |> UserGroup.admin_changeset(%{
          name: "Vip Group #{unique}",
          username_color: "#123456",
          username_effect: "glow"
        })
        |> Repo.insert()

      # User with group1, but nil username_color and nil username_effect
      u1 = create_user()

      {:ok, u1} =
        u1
        |> Ecto.Changeset.change(%{
          primary_group_id: group1.id,
          username_color: nil,
          username_effect: nil
        })
        |> Repo.update()

      # 2. Group with only color (fallback for group.username_color)
      {:ok, group2} =
        %UserGroup{}
        |> UserGroup.admin_changeset(%{
          name: "Color Group #{unique}",
          color: "#654321",
          username_color: nil,
          username_effect: nil
        })
        |> Repo.insert()

      u2 = create_user()

      {:ok, u2} =
        u2
        |> Ecto.Changeset.change(%{
          primary_group_id: group2.id,
          username_color: nil,
          username_effect: nil
        })
        |> Repo.update()

      # 3. User with direct username_color and direct username_effect
      u3 = create_user()

      {:ok, u3} =
        u3
        |> Ecto.Changeset.change(%{username_color: "#abcdef", username_effect: "sparkle"})
        |> Repo.update()

      {_cat, ch} = create_channel()
      {:ok, parent_msg} = Channels.create_message(ch.id, u3.id, %{body: "Parent message"})
      {:ok, thread} = Channels.create_thread(ch.id, parent_msg.id, u3.id, "Style Thread")

      {:ok, _m1} = Channels.create_thread_message(thread.id, u1.id, "From u1")
      {:ok, _m2} = Channels.create_thread_message(thread.id, u2.id, "From u2")
      {:ok, _m3} = Channels.create_thread_message(thread.id, u3.id, "From u3")

      # Allow user_id to be null inside sandbox to test user == nil branch
      Repo.query!("ALTER TABLE chat_thread_messages ALTER COLUMN user_id DROP NOT NULL")

      _m_nil_user =
        %ThreadMessage{
          thread_id: thread.id,
          user_id: nil,
          body: "From deleted user"
        }
        |> Repo.insert!()

      conn =
        conn
        |> auth_conn(u3)
        |> get(~p"/api/chat-threads/#{thread.id}/messages")

      msgs = json_response(conn, 200)["messages"]
      assert length(msgs) == 4

      m3_resp = Enum.find(msgs, &(&1["body"] == "From u3"))
      assert m3_resp["user"]["username_color"] == "#abcdef"
      assert m3_resp["user"]["username_effect"] == "sparkle"

      m1_resp = Enum.find(msgs, &(&1["body"] == "From u1"))
      assert m1_resp["user"]["username_color"] == "#123456"
      assert m1_resp["user"]["username_effect"] == "glow"

      m2_resp = Enum.find(msgs, &(&1["body"] == "From u2"))
      assert m2_resp["user"]["username_color"] == "#654321"
      assert m2_resp["user"]["username_effect"] == "none"

      m_nil_resp = Enum.find(msgs, &(&1["body"] == "From deleted user"))
      assert m_nil_resp["user"] == nil
    end
  end
end
