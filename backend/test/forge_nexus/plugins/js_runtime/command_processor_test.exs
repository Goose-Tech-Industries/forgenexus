defmodule ForgeNexus.Plugins.JsRuntime.CommandProcessorTest do
  use ForgeNexus.DataCase, async: false

  alias ForgeNexus.Plugins.JsRuntime.CommandProcessor
  alias ForgeNexus.{Accounts, Communities, Forums}

  defp create_user do
    uid = System.unique_integer([:positive])

    {:ok, user} =
      Accounts.register_user(%{
        username: "cmd_u_#{uid}",
        email: "cmd_u_#{uid}@example.com",
        password: "ValidPassword123!@#"
      })

    user
  end

  defp create_community(user) do
    uid = System.unique_integer([:positive])

    {:ok, comm} =
      Communities.create_community(%{
        name: "Cmd Comm #{uid}",
        slug: "cmd-comm-#{uid}",
        owner_id: user.id
      })

    comm
  end

  defp create_forum(community) do
    uid = System.unique_integer([:positive])

    {:ok, cat} =
      Forums.create_category(%{
        name: "Cmd Cat #{uid}",
        slug: "cmd-cat-#{uid}",
        position: 1
      })

    {:ok, forum} =
      Forums.create_forum(%{
        name: "Cmd Forum #{uid}",
        slug: "cmd-forum-#{uid}",
        category_id: cat.id,
        position: 1
      })

    {:ok, comm_bin} = Ecto.UUID.dump(community.id)

    from(f in "forums", where: f.id == type(^forum.id, :binary_id))
    |> Repo.update_all(set: [community_id: comm_bin])

    forum
  end

  describe "process/3" do
    test "returns empty list when commands is not a list" do
      assert CommandProcessor.process("invalid", %{}, "user_id") == []
      assert CommandProcessor.process(nil, %{}, "user_id") == []
    end

    test "handles missing command type and permission checks" do
      user = create_user()
      plugin_no_perms = %{manifest: %{"permissions" => []}}

      commands = [
        %{"args" => %{}},
        %{"type" => "create_post", "args" => %{"body" => "Hello"}}
      ]

      results = CommandProcessor.process(commands, plugin_no_perms, user.id)

      assert [
               %{type: "unknown", status: "error", error: "Missing command type"},
               %{
                 type: "create_post",
                 status: "denied",
                 error: "Permission 'create_post' not granted"
               }
             ] = results
    end

    test "executes create_post on success, validation error, and exception" do
      user = create_user()
      comm = create_community(user)
      forum = create_forum(comm)

      {:ok, thread} =
        Forums.create_thread(%{
          title: "Cmd Thread",
          body: "Cmd Thread Body",
          forum_id: forum.id,
          user_id: user.id
        })

      plugin = %{manifest: %{"permissions" => ["create_post"]}}

      commands = [
        # Success
        %{"type" => "create_post", "args" => %{"body" => "New post", "thread_id" => thread.id}},
        # Error (ContentFilter triggers {:error, :spam_detected, _})
        %{
          "type" => "create_post",
          "args" => %{"body" => "buy-now casino poker", "thread_id" => thread.id}
        },
        # Rescue exception (args not a map)
        %{"type" => "create_post", "args" => "not_a_map"}
      ]

      [res1, res2, res3] = CommandProcessor.process(commands, plugin, user.id)

      assert res1.status == "ok"
      assert res1.type == "create_post"
      assert is_binary(res1.id)

      assert res2.status == "error"
      assert res2.type == "create_post"
      assert res2.error == "Failed to create post"

      assert res3.status == "error"
      assert res3.type == "create_post"
      assert is_binary(res3.error)
    end

    test "executes create_thread on success, validation error, and exception" do
      user = create_user()
      comm = create_community(user)
      forum = create_forum(comm)

      plugin = %{manifest: %{"permissions" => ["create_post"]}}

      commands = [
        # Success
        %{
          "type" => "create_thread",
          "args" => %{"title" => "Brand New Thread", "body" => "Content", "forum_id" => forum.id}
        },
        # Error (missing forum_id)
        %{"type" => "create_thread", "args" => %{"title" => "", "forum_id" => nil}},
        # Rescue exception (args not a map)
        %{"type" => "create_thread", "args" => "not_a_map"}
      ]

      [res1, res2, res3] = CommandProcessor.process(commands, plugin, user.id)

      assert res1.status == "ok"
      assert res1.type == "create_thread"
      assert is_binary(res1.id)

      assert res2.status == "error"
      assert res2.type == "create_thread"
      assert res2.error == "Failed to create thread"

      assert res3.status == "error"
      assert res3.type == "create_thread"
      assert is_binary(res3.error)
    end

    test "executes send_dm on success with direct user, conversation, error, and exception" do
      user1 = create_user()
      user2 = create_user()

      plugin = %{manifest: %{"permissions" => ["send_dm"]}}

      # Create direct conversation first
      {:ok, conv} = ForgeNexus.Chat.get_or_create_direct_conversation(user1.id, user2.id)

      commands = [
        # Success via recipient user_id
        %{"type" => "send_dm", "args" => %{"user_id" => user2.id, "body" => "Hello direct"}},
        # Success via conversation_id
        %{"type" => "send_dm", "args" => %{"conversation_id" => conv.id, "body" => "Hello conv"}},
        # Error (missing recipient)
        %{"type" => "send_dm", "args" => %{"body" => "Nowhere"}},
        # Rescue exception (args not a map)
        %{"type" => "send_dm", "args" => "not_a_map"}
      ]

      [res1, res2, res3, res4] = CommandProcessor.process(commands, plugin, user1.id)

      assert res1 == %{type: "send_dm", status: "ok"}
      assert res2 == %{type: "send_dm", status: "ok"}
      assert res3 == %{type: "send_dm", status: "error", error: "Failed to send DM"}
      assert res4.status == "error"
      assert res4.type == "send_dm"
      assert is_binary(res4.error)
    end

    test "handles set_user_data and set_global_data placeholder implementations" do
      user = create_user()
      plugin = %{manifest: %{"permissions" => ["write_data"]}}

      commands = [
        %{"type" => "set_user_data", "args" => %{"key" => "k", "val" => "v"}},
        %{"type" => "set_global_data", "args" => %{"key" => "gk", "val" => "gv"}}
      ]

      [res1, res2] = CommandProcessor.process(commands, plugin, user.id)

      assert res1 == %{
               type: "set_user_data",
               status: "skipped",
               error: "JS plugin data store not yet implemented"
             }

      assert res2 == %{
               type: "set_global_data",
               status: "skipped",
               error: "JS plugin data store not yet implemented"
             }
    end

    test "executes emit_event on success and handles exception" do
      user = create_user()
      plugin = %{manifest: %{"permissions" => ["emit_events"]}}

      Phoenix.PubSub.subscribe(ForgeNexus.PubSub, "plugin:custom_event")

      commands = [
        %{
          "type" => "emit_event",
          "args" => %{"event_name" => "order_completed", "payload" => %{"id" => 123}}
        },
        %{"type" => "emit_event", "args" => "not_a_map"}
      ]

      [res1, res2] = CommandProcessor.process(commands, plugin, user.id)

      assert res1 == %{type: "emit_event", status: "ok"}
      assert_receive {:custom_event, "order_completed", %{"id" => 123}, nil}

      assert res2.status == "error"
      assert res2.type == "emit_event"
      assert is_binary(res2.error)
    end

    test "handles unhandled command types and respects @max_commands limit" do
      user = create_user()
      plugin = %{manifest: %{"permissions" => ["manage_users", "http_request"]}}

      commands = [
        %{"type" => "award_points", "args" => %{}},
        %{"type" => "unregistered_command", "args" => %{}}
      ]

      [res1, res2] = CommandProcessor.process(commands, plugin, user.id)

      assert res1 == %{
               type: "award_points",
               status: "skipped",
               error: "Command type not yet implemented"
             }

      assert res2 == %{
               type: "unregistered_command",
               status: "skipped",
               error: "Command type not yet implemented"
             }

      # Test max commands limit (55 commands should be clamped to 50)
      many_commands =
        for i <- 1..55 do
          %{"type" => "award_points", "args" => %{"index" => i}}
        end

      clamped_results = CommandProcessor.process(many_commands, plugin, user.id)
      assert length(clamped_results) == 50
    end
  end
end
