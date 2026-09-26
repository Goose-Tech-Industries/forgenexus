defmodule ForgeNexusWeb.ChannelAndChatControllerTest do
  use ForgeNexusWeb.ConnCase, async: false

  alias ForgeNexus.Accounts
  alias ForgeNexus.Channels
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
      username: "chat_user_#{unique}",
      email: "chat_user_#{unique}@example.com",
      password: "Fn9#xK8$mQ2!wZ7^vL4*",
      display_name: "Chat User #{unique}"
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

  defp create_category_and_channel do
    unique = System.unique_integer([:positive])

    {:ok, cat} =
      Channels.create_category(%{
        name: "Chat Cat #{unique}",
        slug: "chat-cat-#{unique}",
        position: 1
      })

    {:ok, ch} =
      Channels.create_channel(%{
        name: "General #{unique}",
        slug: "general-#{unique}",
        category_id: cat.id,
        topic: "General Chat",
        position: 1
      })

    {cat, ch}
  end

  # =========================================================================
  # ChannelController Tests
  # =========================================================================
  describe "ChannelController" do
    test "browse channels, view channel, and post message", %{conn: conn} do
      user = create_user()
      {_cat, ch} = create_category_and_channel()

      # 1. GET /api/channels (public/authenticated)
      conn_list = get(fresh_conn(conn), ~p"/api/channels")
      assert is_list(json_response(conn_list, 200)["categories"])

      # 2. GET /api/channels/:slug
      conn_show = get(fresh_conn(conn), ~p"/api/channels/#{ch.slug}")
      show_resp = json_response(conn_show, 200)
      assert show_resp["channel"]["id"] == ch.id
      assert is_list(show_resp["messages"])

      # 3. POST /api/channels/:slug/messages
      conn_msg =
        conn
        |> auth_conn(user)
        |> post(~p"/api/channels/#{ch.slug}/messages", %{"body" => "Hello everyone!"})

      msg_resp = json_response(conn_msg, 201)
      msg_id = msg_resp["message"]["id"]
      assert msg_resp["message"]["body"] == "Hello everyone!"

      # 4. PUT /api/channels/:slug/messages/:message_id
      conn_edit =
        conn
        |> auth_conn(user)
        |> put(~p"/api/channels/#{ch.slug}/messages/#{msg_id}", %{"body" => "Hello updated!"})

      assert json_response(conn_edit, 200)["message"]["body"] == "Hello updated!"

      # 5. GET /api/channels/:slug/messages
      conn_msgs = get(fresh_conn(conn), ~p"/api/channels/#{ch.slug}/messages")
      assert is_list(json_response(conn_msgs, 200)["messages"])

      # 6. DELETE /api/channels/:slug/messages/:message_id
      conn_del =
        conn
        |> auth_conn(user)
        |> delete(~p"/api/channels/#{ch.slug}/messages/#{msg_id}")

      assert json_response(conn_del, 200)["ok"] == true
    end
  end

  # =========================================================================
  # ChatController Tests (Shoutbox & Direct Messages)
  # =========================================================================
  describe "ChatController" do
    test "shoutbox send and read", %{conn: conn} do
      user = create_user()

      # 1. Read shoutbox
      conn_shout_get = get(fresh_conn(conn), ~p"/api/shoutbox")
      assert is_list(json_response(conn_shout_get, 200)["messages"])

      # 2. Send shout
      conn_shout_send =
        conn
        |> auth_conn(user)
        |> post(~p"/api/shoutbox", %{"body" => "First shout!"})

      shout_resp = json_response(conn_shout_send, 201)
      assert shout_resp["message"]["body"] == "First shout!"
    end

    test "direct messaging conversation workflow", %{conn: conn} do
      alice = create_user()
      bob = create_user()

      # 1. Create direct conversation
      conn_dm =
        conn
        |> auth_conn(alice)
        |> post(~p"/api/chat/conversations/direct", %{"user_id" => bob.id})

      dm_resp = json_response(conn_dm, 200)
      conv_id = dm_resp["conversation"]["id"]
      assert conv_id != nil

      # 2. Send message in conversation
      conn_send_dm =
        conn
        |> auth_conn(alice)
        |> post(~p"/api/chat/conversations/#{conv_id}/messages", %{"body" => "Hi Bob!"})

      dm_msg_resp = json_response(conn_send_dm, 201)
      dm_msg_id = dm_msg_resp["message"]["id"]
      assert dm_msg_resp["message"]["body"] == "Hi Bob!"

      # 3. Get messages in conversation
      conn_get_dm =
        conn
        |> auth_conn(bob)
        |> get(~p"/api/chat/conversations/#{conv_id}/messages")

      assert is_list(json_response(conn_get_dm, 200)["messages"])

      # 4. Update message in conversation
      conn_up_dm =
        conn
        |> auth_conn(alice)
        |> put(~p"/api/chat/conversations/#{conv_id}/messages/#{dm_msg_id}", %{
          "body" => "Hi Bob (edited)!"
        })

      assert json_response(conn_up_dm, 200)["message"]["body"] == "Hi Bob (edited)!"

      # 5. Delete message in conversation
      conn_del_dm =
        conn
        |> auth_conn(alice)
        |> delete(~p"/api/chat/conversations/#{conv_id}/messages/#{dm_msg_id}")

      assert json_response(conn_del_dm, 200)["ok"] == true
    end

    test "friendship requests and status", %{conn: conn} do
      alice = create_user()
      bob = create_user()

      # Check initial status
      conn_st =
        conn
        |> auth_conn(alice)
        |> get(~p"/api/friends/status/#{bob.id}")

      assert json_response(conn_st, 200)["status"] == "none"

      # Send friend request
      conn_req =
        conn
        |> auth_conn(alice)
        |> post(~p"/api/friends/request", %{"user_id" => bob.id})

      assert json_response(conn_req, 201)["ok"] == true

      # Bob views friend requests
      conn_reqs =
        conn
        |> auth_conn(bob)
        |> get(~p"/api/friends/requests")

      requests = json_response(conn_reqs, 200)["requests"]
      assert length(requests) >= 1
      req_id = hd(requests)["id"]

      # Bob accepts friend request
      conn_accept =
        conn
        |> auth_conn(bob)
        |> put(~p"/api/friends/#{req_id}/accept")

      assert json_response(conn_accept, 200)["ok"] == true
    end
  end
end
