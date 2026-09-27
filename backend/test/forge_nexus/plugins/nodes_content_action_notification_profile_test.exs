defmodule ForgeNexus.Plugins.NodesContentActionNotificationProfileTest do
  use ForgeNexus.DataCase, async: false

  alias ForgeNexus.Plugins.Engine.Context
  alias ForgeNexus.Repo

  # Action (10)
  # Action (10)
  alias ForgeNexus.Plugins.Nodes.Action.AddToGroup
  alias ForgeNexus.Plugins.Nodes.Action.AwardPoints, as: ActionAwardPoints
  alias ForgeNexus.Plugins.Nodes.Action.CreatePost, as: ActionCreatePost
  alias ForgeNexus.Plugins.Nodes.Action.CreateThread, as: ActionCreateThread
  alias ForgeNexus.Plugins.Nodes.Action.EmitCustomEvent
  alias ForgeNexus.Plugins.Nodes.Action.HttpRequest
  alias ForgeNexus.Plugins.Nodes.Action.RemoveFromGroup
  alias ForgeNexus.Plugins.Nodes.Action.SendDm, as: ActionSendDm
  alias ForgeNexus.Plugins.Nodes.Action.SendNotification
  alias ForgeNexus.Plugins.Nodes.Action.SetCustomTitle, as: ActionSetCustomTitle

  # Content (10)
  alias ForgeNexus.Plugins.Nodes.Content.{
    ArchiveContent,
    CreateThreadNode,
    EditThread,
    EnforceTemplate,
    FeatureContent,
    MergeThreads,
    PinContent,
    SetThreadPrefix,
    SplitPosts,
    UnpinContent
  }

  # Notification (5)
  alias ForgeNexus.Plugins.Nodes.Notification.{
    BroadcastMessage,
    ChannelNotification,
    DigestSummary,
    SendAnnouncement
  }

  alias ForgeNexus.Plugins.Nodes.Notification.SendDm, as: NotificationSendDm

  # Profile (14)
  alias ForgeNexus.Plugins.Nodes.Profile.{
    GrantProfilePerk,
    RestrictProfilePerk,
    SetAvatarFrame,
    SetCustomField,
    SetMood,
    SetNameColor,
    SetNameEffect,
    SetNameplate,
    SetPostbitBackground,
    SetPostbitStyle,
    SetProfileBackground,
    SetSignature,
    ShowProfileWidget
  }

  alias ForgeNexus.Plugins.Nodes.Profile.SetCustomTitle, as: ProfileSetCustomTitle

  defp make_ctx(overrides \\ %{}) do
    defaults = %{
      execution_id: Ecto.UUID.generate(),
      flow_id: Ecto.UUID.generate(),
      community_id: Ecto.UUID.generate(),
      trigger_data: nil,
      triggered_by_id: nil,
      flow_data: %{},
      variables: %{},
      node_trace: [],
      nodes_executed: 0,
      db_operations: 0,
      http_requests: 0,
      loop_iterations: 0,
      started_at: DateTime.utc_now(),
      max_nodes: 200,
      max_db_ops: 50,
      max_http_requests: 5,
      max_loop_iterations: 1000,
      timeout_ms: 30_000
    }

    struct(Context, Map.merge(defaults, overrides))
  end

  defp create_user(attrs \\ %{}) do
    uid = System.unique_integer([:positive])

    %ForgeNexus.Accounts.User{}
    |> ForgeNexus.Accounts.User.registration_changeset(
      Map.merge(
        %{
          username: "user_#{uid}",
          email: "user_#{uid}@example.com",
          password: "Password123!",
          password_confirmation: "Password123!"
        },
        attrs
      )
    )
    |> Repo.insert!()
  end

  defp create_user_group(attrs \\ %{}) do
    uid = System.unique_integer([:positive])

    %ForgeNexus.Accounts.UserGroup{}
    |> ForgeNexus.Accounts.UserGroup.changeset(
      Map.merge(
        %{
          name: "Group #{uid}",
          slug: "group_#{uid}",
          is_default: false
        },
        attrs
      )
    )
    |> Repo.insert!()
  end

  defp create_forum(attrs \\ %{}) do
    uid = System.unique_integer([:positive])

    cat =
      %ForgeNexus.Forums.Category{}
      |> ForgeNexus.Forums.Category.changeset(%{
        name: "Category #{uid}",
        slug: "cat-#{uid}",
        position: 1
      })
      |> Repo.insert!()

    %ForgeNexus.Forums.Forum{}
    |> ForgeNexus.Forums.Forum.changeset(
      Map.merge(
        %{
          name: "Forum #{uid}",
          slug: "forum-#{uid}",
          category_id: cat.id,
          position: 1
        },
        attrs
      )
    )
    |> Repo.insert!()
  end

  defp create_thread(forum, user, attrs \\ %{}) do
    uid = System.unique_integer([:positive])

    %ForgeNexus.Forums.Thread{}
    |> ForgeNexus.Forums.Thread.changeset(
      Map.merge(
        %{
          title: "Thread #{uid}",
          slug: "thread-#{uid}",
          forum_id: forum.id,
          user_id: user.id
        },
        attrs
      )
    )
    |> Repo.insert!()
  end

  defp create_post(thread, user, attrs \\ %{}) do
    %ForgeNexus.Forums.Post{}
    |> ForgeNexus.Forums.Post.changeset(
      Map.merge(
        %{
          body: "Post body content",
          thread_id: thread.id,
          forum_id: thread.forum_id,
          user_id: user.id
        },
        attrs
      )
    )
    |> Repo.insert!()
  end

  # =========================================================================
  # Action Nodes (10)
  # =========================================================================

  describe "Action nodes" do
    test "AddToGroup adds user to group and handles failure" do
      user = create_user()
      group = create_user_group()
      ctx = make_ctx()

      assert %{type: "action/add_to_group"} = AddToGroup.schema()
      assert :ok = AddToGroup.validate_config(%{})

      # Success with atom keys
      {:ok, res, _} = AddToGroup.execute(%{}, %{user_id: user.id, group_id: group.id}, ctx)
      assert res.added == true

      # Success with string keys (already in group or duplicate)
      {:ok, res2, _} =
        AddToGroup.execute(%{}, %{"user_id" => user.id, "group_id" => group.id}, ctx)

      assert is_boolean(res2.added)

      # Failure with invalid group ID
      {:ok, res_err, _} =
        AddToGroup.execute(%{}, %{user_id: user.id, group_id: Ecto.UUID.generate()}, ctx)

      assert res_err.added == false
    end

    test "ActionAwardPoints atomically awards reputation to user" do
      user = create_user(%{reputation: 10})
      ctx = make_ctx()

      assert %{type: "action/award_points"} = ActionAwardPoints.schema()
      assert :ok = ActionAwardPoints.validate_config(%{})

      # Integer points
      {:ok, res, u_ctx} = ActionAwardPoints.execute(%{}, %{user_id: user.id, points: 15}, ctx)
      assert res.awarded == true
      assert res.points == 15
      assert u_ctx.db_operations > ctx.db_operations

      # Float points and string inputs
      {:ok, res2, _} =
        ActionAwardPoints.execute(%{}, %{"user_id" => user.id, "points" => 10.5}, ctx)

      assert res2.points == 10

      # String integer points
      {:ok, res3, _} = ActionAwardPoints.execute(%{}, %{user_id: user.id, points: "20"}, ctx)
      assert res3.points == 20

      # Invalid string points fallback to 0
      {:ok, res4, _} = ActionAwardPoints.execute(%{}, %{user_id: user.id, points: "invalid"}, ctx)
      assert res4.points == 0

      # Non-number/non-string fallback to 0
      {:ok, res5, _} = ActionAwardPoints.execute(%{}, %{user_id: user.id, points: :bad}, ctx)
      assert res5.points == 0

      # User not found
      {:error, err, _} =
        ActionAwardPoints.execute(%{}, %{user_id: Ecto.UUID.generate(), points: 5}, ctx)

      assert err =~ "User not found"
    end

    test "ActionCreatePost creates post in thread and handles error" do
      user = create_user()
      forum = create_forum()
      thread = create_thread(forum, user)
      ctx = make_ctx()

      assert %{type: "action/create_post"} = ActionCreatePost.schema()
      assert :ok = ActionCreatePost.validate_config(%{})

      # Success with atom keys
      {:ok, res, u_ctx} =
        ActionCreatePost.execute(
          %{},
          %{thread_id: thread.id, body: "Great discussion!", user_id: user.id},
          ctx
        )

      assert is_binary(res.post_id)
      assert res.created == true
      assert u_ctx.db_operations > ctx.db_operations

      # Success with string keys
      {:ok, res2, _} =
        ActionCreatePost.execute(
          %{},
          %{"thread_id" => thread.id, "body" => "Another post!", "user_id" => user.id},
          ctx
        )

      assert res2.created == true

      # Failure with invalid changeset (blank body)
      {:error, err, _} =
        ActionCreatePost.execute(%{}, %{thread_id: thread.id, body: "", user_id: user.id}, ctx)

      assert err =~ "Failed to create post"
    end

    test "ActionCreateThread creates thread in forum and handles error" do
      user = create_user()
      forum = create_forum()
      ctx = make_ctx()

      assert %{type: "action/create_thread"} = ActionCreateThread.schema()
      assert :ok = ActionCreateThread.validate_config(%{})

      # Success with atom keys
      {:ok, res, u_ctx} =
        ActionCreateThread.execute(
          %{},
          %{
            forum_id: forum.id,
            title: "Action Thread Test",
            body: "Initial thread post",
            user_id: user.id
          },
          ctx
        )

      assert is_binary(res.thread_id)
      assert res.created == true
      assert u_ctx.db_operations > ctx.db_operations

      # Success with string keys
      {:ok, res2, _} =
        ActionCreateThread.execute(
          %{},
          %{
            "forum_id" => forum.id,
            "title" => "Action Thread String",
            "body" => "Initial body",
            "user_id" => user.id
          },
          ctx
        )

      assert res2.created == true

      # Failure with short title
      {:error, err, _} =
        ActionCreateThread.execute(
          %{},
          %{forum_id: forum.id, title: "T", body: "Short title", user_id: user.id},
          ctx
        )

      assert err =~ "Failed to create thread"
    end

    test "EmitCustomEvent broadcasts event on PubSub and validates config" do
      ctx = make_ctx()

      assert %{type: "action/emit_custom_event"} = EmitCustomEvent.schema()
      assert :ok = EmitCustomEvent.validate_config(%{"event_name" => "order_completed"})
      assert {:error, _} = EmitCustomEvent.validate_config(%{"event_name" => ""})
      assert {:error, _} = EmitCustomEvent.validate_config(%{})

      # Execute with atom payload
      {:ok, res, _} =
        EmitCustomEvent.execute(
          %{"event_name" => "item_unlocked"},
          %{payload: %{"item" => "sword"}},
          ctx
        )

      assert res.emitted == true
      assert res.event_name == "item_unlocked"

      # Execute with string payload
      {:ok, res2, _} =
        EmitCustomEvent.execute(
          %{"event_name" => "badge_awarded"},
          %{"payload" => %{"badge" => "hero"}},
          ctx
        )

      assert res2.emitted == true
    end

    test "HttpRequest performs requests, validates URL, handles SSRF and parses response" do
      ctx = make_ctx()

      assert %{type: "action/http_request"} = HttpRequest.schema()

      assert :ok =
               HttpRequest.validate_config(%{
                 "url" => "https://example.com/api",
                 "method" => "GET"
               })

      assert :ok =
               HttpRequest.validate_config(%{
                 "url" => "https://example.com/api",
                 "method" => "POST"
               })

      assert {:error, _} = HttpRequest.validate_config(%{"url" => ""})

      assert {:error, _} =
               HttpRequest.validate_config(%{
                 "url" => "https://example.com",
                 "method" => "INVALID"
               })

      # URL validation: Invalid scheme (ftp)
      {:error, err_scheme, _} =
        HttpRequest.execute(
          %{"url" => "ftp://example.com/file", "method" => "GET"},
          %{},
          ctx
        )

      assert err_scheme =~ "Only HTTP(S)"

      # URL validation: Missing host
      {:error, err_host, _} =
        HttpRequest.execute(
          %{"url" => "http://", "method" => "GET"},
          %{},
          ctx
        )

      assert err_host =~ "missing host"

      # SSRF protection: Blocked private IP when allow_local_http is false (default)
      Application.put_env(:forge_nexus, :allow_local_http, false)

      {:error, err_ssrf, _} =
        HttpRequest.execute(
          %{"url" => "http://127.0.0.1:4000/test", "method" => "GET"},
          %{},
          ctx
        )

      assert err_ssrf =~ "blocked private IP"

      {:error, err_ssrf2, _} =
        HttpRequest.execute(
          %{"url" => "http://172.16.1.1:4000/test", "method" => "GET"},
          %{},
          ctx
        )

      assert err_ssrf2 =~ "blocked private IP"

      {:error, err_ssrf3, _} =
        HttpRequest.execute(
          %{"url" => "http://192.168.1.1:4000/test", "method" => "GET"},
          %{},
          ctx
        )

      assert err_ssrf3 =~ "blocked private IP"

      # DNS error fallback returns :ok from validate_url and proceeds to make_request (which fails with connection error)
      {:error, err_dns, _} =
        HttpRequest.execute(
          %{"url" => "http://unresolvable-domain-12345.local/test", "method" => "GET"},
          %{},
          ctx
        )

      assert err_dns =~ "HTTP request failed"

      # Start TestMockHttpServer and enable allow_local_http
      {server_pid, port} = ForgeNexus.TestMockHttpServer.start()
      Application.put_env(:forge_nexus, :allow_local_http, true)

      on_exit(fn ->
        Application.put_env(:forge_nexus, :allow_local_http, false)

        try do
          Process.exit(server_pid, :shutdown)
        catch
          _, _ -> :ok
        end
      end)

      # Successful POST request with JSON body, template substitution, and header matching
      {:ok, res_post, u_ctx} =
        HttpRequest.execute(
          %{
            "url" => "http://127.0.0.1:#{port}/webhook/success?user={{user_name}}",
            "method" => "POST",
            "headers" => %{"Content-Type" => "application/json", "X-Custom" => "val"},
            "body_template" => "{\"user\": \"{{user_name}}\"}"
          },
          %{"user_name" => "alex"},
          ctx
        )

      assert res_post.status == 200
      assert res_post.body["status"] == "delivered"
      assert res_post.body["ok"] == true
      assert u_ctx.http_requests > ctx.http_requests

      # Non-JSON plain text response (hits 404 text on mock server)
      {:ok, res_text, _} =
        HttpRequest.execute(
          %{
            "url" => "http://127.0.0.1:#{port}/unknown-path",
            "method" => "GET"
          },
          %{},
          ctx
        )

      assert res_text.status == 404
      assert res_text.body == "not found"

      # Large response truncation (> 1MB)
      {:ok, res_large, _} =
        HttpRequest.execute(
          %{
            "url" => "http://127.0.0.1:#{port}/large",
            "method" => "GET"
          },
          %{},
          ctx
        )

      assert res_large.status == 200
      assert byte_size(res_large.body) == 1_048_576

      # Non-binary body template fallback
      {:ok, res_fallback, _} =
        HttpRequest.execute(
          %{
            "url" => "http://127.0.0.1:#{port}/webhook/success",
            "method" => "POST",
            "body_template" => nil
          },
          %{},
          ctx
        )

      assert res_fallback.status == 200

      # Other methods: DELETE and HEAD
      {:ok, res_del, _} =
        HttpRequest.execute(
          %{"url" => "http://127.0.0.1:#{port}/resource", "method" => "DELETE"},
          %{},
          ctx
        )

      assert res_del.status == 404

      {:ok, res_head, _} =
        HttpRequest.execute(
          %{"url" => "http://127.0.0.1:#{port}/resource", "method" => "HEAD"},
          %{},
          ctx
        )

      assert res_head.status == 404

      # PUT and PATCH methods
      {:ok, res_put, _} =
        HttpRequest.execute(
          %{"url" => "http://127.0.0.1:#{port}/resource", "method" => "PUT"},
          %{},
          ctx
        )

      assert res_put.status == 404

      {:ok, res_patch, _} =
        HttpRequest.execute(
          %{"url" => "http://127.0.0.1:#{port}/resource", "method" => "PATCH"},
          %{},
          ctx
        )

      assert res_patch.status == 404

      # Unknown method fallback _ -> :get
      {:error, err_custom, _} =
        HttpRequest.execute(
          %{"url" => "http://127.0.0.1:#{port}/resource", "method" => "UNKNOWN"},
          %{},
          ctx
        )

      assert err_custom =~ "HTTP request failed"

      # Connection failure (port 1 connection refused)
      {:error, err_conn, _} =
        HttpRequest.execute(
          %{"url" => "http://127.0.0.1:1/refused", "method" => "GET"},
          %{},
          ctx
        )

      assert err_conn =~ "HTTP request failed"

      Application.put_env(:forge_nexus, :allow_local_http, false)
    end

    test "RemoveFromGroup removes membership and handles atom / string keys" do
      user = create_user()
      group = create_user_group()
      ForgeNexus.Accounts.add_user_to_group(user.id, group.id)
      ctx = make_ctx()

      assert %{type: "action/remove_from_group"} = RemoveFromGroup.schema()
      assert :ok = RemoveFromGroup.validate_config(%{})

      # Success with atom keys
      {:ok, res, _} = RemoveFromGroup.execute(%{}, %{user_id: user.id, group_id: group.id}, ctx)
      assert res.removed == true

      # User already removed
      {:ok, res2, _} =
        RemoveFromGroup.execute(%{}, %{"user_id" => user.id, "group_id" => group.id}, ctx)

      assert res2.removed == false
    end

    test "ActionSendDm creates system direct message and handles invalid user" do
      user = create_user()
      ctx = make_ctx()

      assert %{type: "action/send_dm"} = ActionSendDm.schema()
      assert :ok = ActionSendDm.validate_config(%{})

      # Success with atom keys
      {:ok, res, _} = ActionSendDm.execute(%{}, %{user_id: user.id, body: "Hello User!"}, ctx)
      assert res.sent == true

      # Success with string keys
      {:ok, res2, _} =
        ActionSendDm.execute(%{}, %{"user_id" => user.id, "body" => "Welcome!"}, ctx)

      assert res2.sent == true

      # Failure with nil user
      {:ok, res_err, _} = ActionSendDm.execute(%{}, %{user_id: nil, body: "Fail"}, ctx)
      assert res_err.sent == false
    end

    test "SendNotification creates system notification and handles failure" do
      user = create_user()
      ctx = make_ctx()

      assert %{type: "action/send_notification"} = SendNotification.schema()
      assert :ok = SendNotification.validate_config(%{})

      # Success with atom keys
      {:ok, res, _} =
        SendNotification.execute(
          %{},
          %{user_id: user.id, title: "Alert", body: "Check this out", link: "/thread/1"},
          ctx
        )

      assert res.sent == true

      # Success with string keys
      {:ok, res2, _} =
        SendNotification.execute(
          %{},
          %{"user_id" => user.id, "title" => "Update", "body" => "New content"},
          ctx
        )

      assert res2.sent == true

      # Failure with nil user
      {:ok, res_err, _} =
        SendNotification.execute(%{}, %{user_id: nil, title: "Bad", body: "Bad"}, ctx)

      assert res_err.sent == false
    end

    test "ActionSetCustomTitle updates custom title and handles non-existent user" do
      user = create_user()
      ctx = make_ctx()

      assert %{type: "action/set_custom_title"} = ActionSetCustomTitle.schema()
      assert :ok = ActionSetCustomTitle.validate_config(%{})

      # Success with atom keys
      {:ok, res, u_ctx} =
        ActionSetCustomTitle.execute(%{}, %{user_id: user.id, title: "Elite Member"}, ctx)

      assert res.updated == true
      assert u_ctx.db_operations > ctx.db_operations

      # Success with string keys
      {:ok, res2, _} =
        ActionSetCustomTitle.execute(%{}, %{"user_id" => user.id, "title" => "Moderator"}, ctx)

      assert res2.updated == true

      # Non-existent user
      {:error, err, _} =
        ActionSetCustomTitle.execute(%{}, %{user_id: Ecto.UUID.generate(), title: "Ghost"}, ctx)

      assert err =~ "User not found"
    end
  end

  # =========================================================================
  # Content Nodes (10)
  # =========================================================================

  describe "Content nodes" do
    test "ArchiveContent archives thread to archive forum and handles errors" do
      user = create_user()
      forum = create_forum()
      _archive_forum = create_forum(%{slug: "archive"})
      thread = create_thread(forum, user)
      ctx = make_ctx()

      assert %{type: "content/archive_content"} = ArchiveContent.schema()
      assert :ok = ArchiveContent.validate_config(%{})

      # Success with default archive slug
      {:ok, res, u_ctx} = ArchiveContent.execute(%{}, %{thread_id: thread.id}, ctx)
      assert res.success == true
      assert u_ctx.db_operations > ctx.db_operations

      # Success with string keys and custom config slug
      archive2 = create_forum(%{slug: "custom_archive"})
      thread2 = create_thread(forum, user)

      {:ok, res2, _} =
        ArchiveContent.execute(
          %{"archive_forum_slug" => archive2.slug},
          %{"thread_id" => thread2.id},
          ctx
        )

      assert res2.success == true

      # Error with non-existent thread
      {:error, err, _} =
        ArchiveContent.execute(%{}, %{thread_id: Ecto.UUID.generate()}, ctx)

      assert err =~ "Failed to archive"
    end

    test "CreateThreadNode creates thread with tags, prefix, and validates config" do
      user = create_user()
      forum = create_forum()
      ctx = make_ctx()

      assert %{type: "content/create_thread"} = CreateThreadNode.schema()
      assert :ok = CreateThreadNode.validate_config(%{})

      # Success with tags and prefix
      {:ok, res, u_ctx} =
        CreateThreadNode.execute(
          %{"tags" => "guides, tech, elx", "prefix" => "Guide"},
          %{
            forum_id: forum.id,
            user_id: user.id,
            title: "Complete Guide to Flows",
            body: "Full tutorial"
          },
          ctx
        )

      assert is_binary(res.thread_id)
      assert is_binary(res.slug)
      assert res.success == true
      assert u_ctx.db_operations > ctx.db_operations

      # Success with empty prefix, empty tags, string keys
      {:ok, res2, _} =
        CreateThreadNode.execute(
          %{"tags" => "", "prefix" => ""},
          %{
            "forum_id" => forum.id,
            "user_id" => user.id,
            "title" => "Vanilla Thread Example",
            "body" => "No tags here"
          },
          ctx
        )

      assert res2.success == true

      # Error branch with short title
      {:error, err, _} =
        CreateThreadNode.execute(
          %{},
          %{forum_id: forum.id, user_id: user.id, title: "T", body: "Too short"},
          ctx
        )

      assert err =~ "Failed to create thread"
    end

    test "EditThread updates thread title, prefix, tags and handles error" do
      user = create_user()
      forum = create_forum()
      thread = create_thread(forum, user, %{title: "Old Title"})
      ctx = make_ctx()

      assert %{type: "content/edit_thread"} = EditThread.schema()
      assert :ok = EditThread.validate_config(%{})

      # Success with all updates
      {:ok, res, u_ctx} =
        EditThread.execute(
          %{"tags" => "updated, rules, "},
          %{thread_id: thread.id, title: "New Title", prefix: "Solved"},
          ctx
        )

      assert res.success == true
      assert u_ctx.db_operations > ctx.db_operations

      # Success with string keys and partial updates
      {:ok, res2, _} =
        EditThread.execute(
          %{"tags" => ""},
          %{"thread_id" => thread.id, "title" => "Updated Again"},
          ctx
        )

      assert res2.success == true

      # Error with non-existent thread
      {:error, err, _} =
        EditThread.execute(%{}, %{thread_id: Ecto.UUID.generate()}, ctx)

      assert err =~ "Failed to edit thread"
    end

    test "EnforceTemplate verifies content sections and validates config" do
      ctx = make_ctx()

      assert %{type: "content/enforce_template"} = EnforceTemplate.schema()

      assert :ok =
               EnforceTemplate.validate_config(%{
                 "required_sections" => "Bug Description, Steps to Reproduce"
               })

      assert {:error, _} = EnforceTemplate.validate_config(%{"required_sections" => ""})
      assert {:error, _} = EnforceTemplate.validate_config(%{})

      config = %{"required_sections" => "Description, Steps, Expected"}

      # Valid branch
      prev_level = Logger.level()
      Logger.configure(level: :debug)
      valid_content = "Here is the Description: Works! And the Steps: None. Expected: Success."

      {:branch, "valid", %{missing_sections: missing}, _} =
        EnforceTemplate.execute(config, %{content: valid_content}, ctx)

      Logger.configure(level: prev_level)

      assert missing == []

      # Invalid branch with string keys
      partial_content = "Only contains description here."

      {:branch, "invalid", %{missing_sections: missing_parts}, _} =
        EnforceTemplate.execute(config, %{"content" => partial_content}, ctx)

      assert length(missing_parts) >= 2
    end

    test "FeatureContent features thread in position and validates config" do
      user = create_user()
      forum = create_forum()
      thread = create_thread(forum, user)
      ctx = make_ctx()

      assert %{type: "content/feature_content"} = FeatureContent.schema()
      assert :ok = FeatureContent.validate_config(%{"position" => "homepage"})
      assert :ok = FeatureContent.validate_config(%{"position" => "sidebar"})
      assert :ok = FeatureContent.validate_config(%{"position" => "banner"})
      assert {:error, _} = FeatureContent.validate_config(%{"position" => "footer"})

      future_iso = DateTime.utc_now() |> DateTime.add(86400, :second) |> DateTime.to_iso8601()

      # Success with atom keys
      {:ok, res, u_ctx} =
        FeatureContent.execute(
          %{"position" => "homepage", "featured_until" => future_iso},
          %{thread_id: thread.id},
          ctx
        )

      assert res.success == true
      assert u_ctx.db_operations > ctx.db_operations

      # Success with string keys
      {:ok, res2, _} =
        FeatureContent.execute(
          %{"position" => "sidebar"},
          %{"thread_id" => thread.id},
          ctx
        )

      assert res2.success == true

      # Error branch with invalid thread
      {:error, err, _} =
        FeatureContent.execute(%{}, %{thread_id: Ecto.UUID.generate()}, ctx)

      assert err =~ "Failed to feature"
    end

    test "MergeThreads moves posts into target thread and handles errors" do
      user = create_user()
      forum = create_forum()
      source = create_thread(forum, user)
      target = create_thread(forum, user)
      _post = create_post(source, user)
      ctx = make_ctx()

      assert %{type: "content/merge_threads"} = MergeThreads.schema()
      assert :ok = MergeThreads.validate_config(%{})

      # Success with atom keys
      {:ok, res, u_ctx} =
        MergeThreads.execute(
          %{},
          %{source_thread_id: source.id, target_thread_id: target.id},
          ctx
        )

      assert res.success == true
      assert is_integer(res.merged_post_count)
      assert u_ctx.db_operations > ctx.db_operations

      # Success with string keys
      source2 = create_thread(forum, user, %{title: "Source 2"})

      {:ok, res_str, _} =
        MergeThreads.execute(
          %{},
          %{"source_thread_id" => source2.id, "target_thread_id" => target.id},
          ctx
        )

      assert res_str.success == true

      # Error with invalid IDs
      {:error, err, _} =
        MergeThreads.execute(
          %{},
          %{"source_thread_id" => Ecto.UUID.generate(), "target_thread_id" => target.id},
          ctx
        )

      assert err =~ "Failed to merge threads"
    end

    test "PinContent and UnpinContent pin and unpin thread targets" do
      user = create_user()
      forum = create_forum()
      thread = create_thread(forum, user)
      ctx = make_ctx()

      assert %{type: "content/pin_content"} = PinContent.schema()
      assert :ok = PinContent.validate_config(%{})
      assert %{type: "content/unpin_content"} = UnpinContent.schema()
      assert :ok = UnpinContent.validate_config(%{})

      # Pin success with atom keys
      {:ok, res_pin, u_ctx} =
        PinContent.execute(%{}, %{target_type: "thread", target_id: thread.id}, ctx)

      assert res_pin.success == true
      assert u_ctx.db_operations > ctx.db_operations

      # Pin error with unsupported target type
      {:error, err_pin, _} =
        PinContent.execute(%{}, %{target_type: "unknown", target_id: thread.id}, ctx)

      assert err_pin =~ "Failed to pin"

      # Unpin success with string keys
      {:ok, res_unpin, u_ctx2} =
        UnpinContent.execute(%{}, %{"target_type" => "thread", "target_id" => thread.id}, ctx)

      assert res_unpin.success == true
      assert u_ctx2.db_operations > ctx.db_operations

      # Unpin error with unsupported target type
      {:error, err_unpin, _} =
        UnpinContent.execute(%{}, %{target_type: "other", target_id: thread.id}, ctx)

      assert err_unpin =~ "Failed to unpin"
    end

    test "SetThreadPrefix updates thread prefix and handles errors" do
      user = create_user()
      forum = create_forum()
      thread = create_thread(forum, user)
      ctx = make_ctx()

      assert %{type: "content/set_thread_prefix"} = SetThreadPrefix.schema()
      assert :ok = SetThreadPrefix.validate_config(%{})

      # Success with atom keys
      {:ok, res, u_ctx} =
        SetThreadPrefix.execute(%{}, %{thread_id: thread.id, prefix: "Tutorial"}, ctx)

      assert res.success == true
      assert u_ctx.db_operations > ctx.db_operations

      # Success with string keys
      {:ok, res2, _} =
        SetThreadPrefix.execute(%{}, %{"thread_id" => thread.id, "prefix" => "Help"}, ctx)

      assert res2.success == true

      # Error with non-existent thread
      {:error, err, _} =
        SetThreadPrefix.execute(%{}, %{thread_id: Ecto.UUID.generate(), prefix: "Test"}, ctx)

      assert err =~ "Failed to set prefix"
    end

    test "SplitPosts moves selected posts into a new thread" do
      user = create_user()
      forum = create_forum()
      thread = create_thread(forum, user)
      post1 = create_post(thread, user, %{body: "Splittable post 1"})
      post2 = create_post(thread, user, %{body: "Splittable post 2"})
      ctx = make_ctx()

      assert %{type: "content/split_posts"} = SplitPosts.schema()
      assert :ok = SplitPosts.validate_config(%{})

      # Success with list of post IDs
      {:ok, res, u_ctx} =
        SplitPosts.execute(
          %{},
          %{
            post_ids: [post1.id, post2.id],
            new_thread_title: "Split Out Discussion",
            forum_id: forum.id
          },
          ctx
        )

      assert is_binary(res.new_thread_id)
      assert res.posts_moved >= 1
      assert res.success == true
      assert u_ctx.db_operations > ctx.db_operations

      # JSON string post_ids and string keys
      post3 = create_post(thread, user, %{body: "Splittable post 3"})
      json_ids = Jason.encode!([post3.id])

      {:ok, res2, _} =
        SplitPosts.execute(
          %{},
          %{
            "post_ids" => json_ids,
            "new_thread_title" => "Split Discussion 2",
            "forum_id" => forum.id
          },
          ctx
        )

      assert res2.success == true

      # Invalid JSON string fallback to []
      {:error, err_empty, _} =
        SplitPosts.execute(
          %{},
          %{post_ids: "invalid_json", new_thread_title: "Title", forum_id: forum.id},
          ctx
        )

      assert err_empty =~ "Failed to split posts"

      # Non-list and non-string fallback to []
      {:error, err_bad, _} =
        SplitPosts.execute(
          %{},
          %{post_ids: 12345, new_thread_title: "Title", forum_id: forum.id},
          ctx
        )

      assert err_bad =~ "Failed to split posts"

      # JSON string representing a map (not a list) fallback to []
      {:error, err_map, _} =
        SplitPosts.execute(
          %{},
          %{
            post_ids: Jason.encode!(%{"key" => "val"}),
            new_thread_title: "Title",
            forum_id: forum.id
          },
          ctx
        )

      assert err_map =~ "Failed to split posts"

      # Nonexistent post IDs trigger rescue
      {:error, err_rescue, _} =
        SplitPosts.execute(
          %{},
          %{post_ids: [Ecto.UUID.generate()], new_thread_title: "Title", forum_id: forum.id},
          ctx
        )

      assert err_rescue =~ "Failed to split posts"
    end
  end

  # =========================================================================
  # Notification Nodes (5)
  # =========================================================================

  describe "Notification nodes" do
    test "BroadcastMessage broadcasts to all, group, and online, and validates config" do
      ctx = make_ctx()

      assert %{type: "notification/broadcast_message"} = BroadcastMessage.schema()
      assert :ok = BroadcastMessage.validate_config(%{"target" => "all"})
      assert :ok = BroadcastMessage.validate_config(%{"target" => "online"})
      assert :ok = BroadcastMessage.validate_config(%{"target" => "group", "group_id" => "grp_1"})

      assert {:error, _} =
               BroadcastMessage.validate_config(%{"target" => "group", "group_id" => ""})

      assert {:error, _} = BroadcastMessage.validate_config(%{"target" => "invalid"})

      # Broadcast to all
      {:ok, res1, _} =
        BroadcastMessage.execute(%{"target" => "all"}, %{message: "Hello All!"}, ctx)

      assert res1.success == true

      # Broadcast to online
      {:ok, res2, _} =
        BroadcastMessage.execute(
          %{"target" => "online"},
          %{"message" => "Hello Active Users!"},
          ctx
        )

      assert res2.success == true

      # Broadcast to group
      {:ok, res3, _} =
        BroadcastMessage.execute(
          %{"target" => "group", "group_id" => "mod_team"},
          %{message: "Mod Notice"},
          ctx
        )

      assert res3.success == true
    end

    test "ChannelNotification sends message to chat channel via PubSub" do
      ctx = make_ctx()

      assert %{type: "notification/channel_notification"} = ChannelNotification.schema()
      assert :ok = ChannelNotification.validate_config(%{})

      # Success with atom keys and is_embed true
      {:ok, res1, _} =
        ChannelNotification.execute(
          %{"is_embed" => true},
          %{channel_id: "general", message: "Important announcement!"},
          ctx
        )

      assert res1.success == true

      # Success with string keys and default embed false
      {:ok, res2, _} =
        ChannelNotification.execute(
          %{},
          %{"channel_id" => "general", "message" => "Normal text"},
          ctx
        )

      assert res2.success == true
    end

    test "DigestSummary generates summary skeleton and validates config" do
      user = create_user()
      ctx = make_ctx()

      assert %{type: "notification/digest_summary"} = DigestSummary.schema()
      assert :ok = DigestSummary.validate_config(%{"period" => "daily"})
      assert :ok = DigestSummary.validate_config(%{"period" => "weekly"})
      assert {:error, _} = DigestSummary.validate_config(%{"period" => "monthly"})

      # Daily digest
      {:ok, res_daily, u_ctx} =
        DigestSummary.execute(%{"period" => "daily"}, %{user_id: user.id}, ctx)

      assert res_daily.summary.period == "daily"
      assert res_daily.summary.user_id == user.id
      assert u_ctx.db_operations > ctx.db_operations

      # Weekly digest with string keys
      {:ok, res_weekly, _} =
        DigestSummary.execute(%{"period" => "weekly"}, %{"user_id" => user.id}, ctx)

      assert res_weekly.summary.period == "weekly"

      # User not found
      {:error, err, _} =
        DigestSummary.execute(%{}, %{user_id: Ecto.UUID.generate()}, ctx)

      assert err =~ "User not found"
    end

    test "SendAnnouncement broadcasts to channel and validates config" do
      ctx = make_ctx()

      assert %{type: "notification/send_announcement"} = SendAnnouncement.schema()
      assert :ok = SendAnnouncement.validate_config(%{"channel" => "general"})
      assert {:error, _} = SendAnnouncement.validate_config(%{"channel" => ""})
      assert {:error, _} = SendAnnouncement.validate_config(%{})

      # Success with atom keys
      {:ok, res, _} =
        SendAnnouncement.execute(
          %{"channel" => "news"},
          %{title: "Server Update", body: "Maintenance tonight"},
          ctx
        )

      assert res.success == true

      # Success with string keys
      {:ok, res2, _} =
        SendAnnouncement.execute(
          %{"channel" => "news"},
          %{"title" => "Downtime Complete", "body" => "All servers live"},
          ctx
        )

      assert res2.success == true
    end

    test "NotificationSendDm sends system or direct message to user" do
      user = create_user()
      ctx = make_ctx()

      assert %{type: "notification/send_dm"} = NotificationSendDm.schema()
      assert :ok = NotificationSendDm.validate_config(%{})

      # From system = true
      {:ok, res_sys, u_ctx} =
        NotificationSendDm.execute(
          %{"from_system" => true},
          %{user_id: user.id, body: "System notification message"},
          ctx
        )

      assert res_sys.success == true
      assert is_binary(res_sys.conversation_id)
      assert u_ctx.db_operations > ctx.db_operations

      # From system = false and string keys
      {:ok, res_user, _} =
        NotificationSendDm.execute(
          %{"from_system" => false},
          %{"user_id" => user.id, "body" => "User direct message"},
          ctx
        )

      assert res_user.success == true

      # User not found
      {:error, err, _} =
        NotificationSendDm.execute(%{}, %{user_id: Ecto.UUID.generate(), body: "Ghost"}, ctx)

      assert err =~ "User not found"

      # Error branch when notification insert fails due to invalid body type
      {:error, err_fail, _} =
        NotificationSendDm.execute(%{}, %{user_id: user.id, body: %{not: "a string"}}, ctx)

      assert err_fail =~ "Failed to send DM"
    end
  end

  # =========================================================================
  # Profile Nodes (14)
  # =========================================================================

  describe "Profile nodes" do
    test "GrantProfilePerk grants perks and validates config" do
      user = create_user()
      ctx = make_ctx()

      assert %{type: "profile/grant_profile_perk"} = GrantProfilePerk.schema()
      assert :ok = GrantProfilePerk.validate_config(%{"perk_type" => "custom_title"})
      assert :ok = GrantProfilePerk.validate_config(%{"perk_type" => "avatar_frame"})
      assert {:error, _} = GrantProfilePerk.validate_config(%{"perk_type" => "admin_perk"})

      # Grant fresh perk
      {:ok, res1, u_ctx} =
        GrantProfilePerk.execute(
          %{"perk_type" => "custom_title"},
          %{user_id: user.id},
          ctx
        )

      assert res1.success == true
      assert u_ctx.db_operations > ctx.db_operations

      # Grant existing perk (hits perk in perks branch)
      {:ok, res2, _} =
        GrantProfilePerk.execute(
          %{"perk_type" => "custom_title"},
          %{"user_id" => user.id},
          ctx
        )

      assert res2.success == true

      # User not found
      {:error, err, _} =
        GrantProfilePerk.execute(%{}, %{user_id: Ecto.UUID.generate()}, ctx)

      assert err =~ "User not found"
    end

    test "RestrictProfilePerk revokes perks and validates config" do
      user =
        create_user(%{
          custom_title: "VIP",
          avatar_frame: "gold_frame",
          username_color: "#FF0000",
          username_effect: "glow",
          postbit_background_url: "https://example.com/bg.png",
          profile_background_url: "https://example.com/profile.png"
        })

      ctx = make_ctx()

      assert %{type: "profile/restrict_profile_perk"} = RestrictProfilePerk.schema()
      assert :ok = RestrictProfilePerk.validate_config(%{"perk_type" => "custom_title"})
      assert :ok = RestrictProfilePerk.validate_config(%{"perk_type" => "avatar_frame"})
      assert {:error, _} = RestrictProfilePerk.validate_config(%{"perk_type" => "bad_perk"})

      for perk <-
            ~w(avatar_frame name_color name_effect postbit_background profile_background custom_title) do
        {:ok, res, _} =
          RestrictProfilePerk.execute(%{"perk_type" => perk}, %{user_id: user.id}, ctx)

        assert res.success == true
      end

      # String keys
      {:ok, res_str, _} =
        RestrictProfilePerk.execute(
          %{"perk_type" => "custom_title"},
          %{"user_id" => user.id},
          ctx
        )

      assert res_str.success == true

      # User not found
      {:error, err, _} =
        RestrictProfilePerk.execute(%{}, %{user_id: Ecto.UUID.generate()}, ctx)

      assert err =~ "User not found"
    end

    test "SetAvatarFrame sets user avatar frame" do
      user = create_user()
      ctx = make_ctx()

      assert %{type: "profile/set_avatar_frame"} = SetAvatarFrame.schema()
      assert :ok = SetAvatarFrame.validate_config(%{})

      # Success with atom keys
      {:ok, res, u_ctx} =
        SetAvatarFrame.execute(%{}, %{user_id: user.id, frame_id: "diamond_frame"}, ctx)

      assert res.success == true
      assert u_ctx.db_operations > ctx.db_operations

      # Success with string keys
      {:ok, res2, _} =
        SetAvatarFrame.execute(%{}, %{"user_id" => user.id, "frame_id" => "ruby_frame"}, ctx)

      assert res2.success == true

      # User not found
      {:error, err, _} =
        SetAvatarFrame.execute(%{}, %{user_id: Ecto.UUID.generate(), frame_id: "frame"}, ctx)

      assert err =~ "User not found"
    end

    test "SetCustomField updates custom fields in metadata" do
      user = create_user()
      ctx = make_ctx()

      assert %{type: "profile/set_custom_field"} = SetCustomField.schema()
      assert :ok = SetCustomField.validate_config(%{})

      # Success with atom keys
      {:ok, res, u_ctx} =
        SetCustomField.execute(
          %{},
          %{user_id: user.id, field_name: "favorite_color", field_value: "Purple"},
          ctx
        )

      assert res.success == true
      assert u_ctx.db_operations > ctx.db_operations

      # Success with string keys
      {:ok, res2, _} =
        SetCustomField.execute(
          %{},
          %{"user_id" => user.id, "field_name" => "hobby", "field_value" => "Gaming"},
          ctx
        )

      assert res2.success == true

      # User not found
      {:error, err, _} =
        SetCustomField.execute(
          %{},
          %{user_id: Ecto.UUID.generate(), field_name: "k", field_value: "v"},
          ctx
        )

      assert err =~ "User not found"
    end

    test "ProfileSetCustomTitle sets title from config" do
      user = create_user()
      ctx = make_ctx()

      assert %{type: "profile/set_custom_title"} = ProfileSetCustomTitle.schema()
      assert :ok = ProfileSetCustomTitle.validate_config(%{})

      # Success with atom keys
      {:ok, res, u_ctx} =
        ProfileSetCustomTitle.execute(
          %{"title" => "Community Champion"},
          %{user_id: user.id},
          ctx
        )

      assert res.success == true
      assert u_ctx.db_operations > ctx.db_operations

      # Success with string keys
      {:ok, res2, _} =
        ProfileSetCustomTitle.execute(%{"title" => "Veteran"}, %{"user_id" => user.id}, ctx)

      assert res2.success == true

      # User not found
      {:error, err, _} =
        ProfileSetCustomTitle.execute(%{}, %{user_id: Ecto.UUID.generate()}, ctx)

      assert err =~ "User not found"
    end

    test "SetMood sets emoji and text status" do
      user = create_user()
      ctx = make_ctx()

      assert %{type: "profile/set_mood"} = SetMood.schema()
      assert :ok = SetMood.validate_config(%{})

      # Success with atom keys
      {:ok, res, u_ctx} =
        SetMood.execute(%{}, %{user_id: user.id, emoji: "🚀", text: "Ready to launch"}, ctx)

      assert res.success == true
      assert u_ctx.db_operations > ctx.db_operations

      # Success with string keys
      {:ok, res2, _} =
        SetMood.execute(
          %{},
          %{"user_id" => user.id, "emoji" => "☕", "text" => "Coffee break"},
          ctx
        )

      assert res2.success == true

      # User not found
      {:error, err, _} =
        SetMood.execute(%{}, %{user_id: Ecto.UUID.generate(), emoji: "🎮", text: "Gaming"}, ctx)

      assert err =~ "User not found"
    end

    test "SetNameColor sets display name color" do
      user = create_user()
      ctx = make_ctx()

      assert %{type: "profile/set_name_color"} = SetNameColor.schema()
      assert :ok = SetNameColor.validate_config(%{})

      # Success with atom keys
      {:ok, res, u_ctx} =
        SetNameColor.execute(%{}, %{user_id: user.id, color: "#FFAA00"}, ctx)

      assert res.success == true
      assert u_ctx.db_operations > ctx.db_operations

      # Success with string keys
      {:ok, res2, _} =
        SetNameColor.execute(%{}, %{"user_id" => user.id, "color" => "#00FFAA"}, ctx)

      assert res2.success == true

      # User not found
      {:error, err, _} =
        SetNameColor.execute(%{}, %{user_id: Ecto.UUID.generate(), color: "#FFFFFF"}, ctx)

      assert err =~ "User not found"
    end

    test "SetNameEffect sets visual effect and validates config" do
      user = create_user()
      ctx = make_ctx()

      assert %{type: "profile/set_name_effect"} = SetNameEffect.schema()

      for effect <- ~w(none glow bold italic rainbow sparkle) do
        assert :ok = SetNameEffect.validate_config(%{"effect" => effect})
      end

      assert {:error, _} = SetNameEffect.validate_config(%{"effect" => "fire"})

      # Success with atom keys
      {:ok, res, u_ctx} =
        SetNameEffect.execute(%{"effect" => "glow"}, %{user_id: user.id}, ctx)

      assert res.success == true
      assert u_ctx.db_operations > ctx.db_operations

      # Success with string keys
      {:ok, res2, _} =
        SetNameEffect.execute(%{"effect" => "rainbow"}, %{"user_id" => user.id}, ctx)

      assert res2.success == true

      # User not found
      {:error, err, _} =
        SetNameEffect.execute(%{}, %{user_id: Ecto.UUID.generate()}, ctx)

      assert err =~ "User not found"
    end

    test "SetNameplate sets nameplate color and validates hex config" do
      user = create_user()
      ctx = make_ctx()

      assert %{type: "profile/set_nameplate"} = SetNameplate.schema()
      assert :ok = SetNameplate.validate_config(%{"color" => "#ff0000"})
      assert :ok = SetNameplate.validate_config(%{"color" => "#abc"})
      assert :ok = SetNameplate.validate_config(%{"color" => ""})
      assert {:error, _} = SetNameplate.validate_config(%{"color" => "not_hex"})

      # Success with atom keys
      {:ok, res, u_ctx} =
        SetNameplate.execute(%{"color" => "#336699"}, %{user_id: user.id}, ctx)

      assert res.success == true
      assert u_ctx.db_operations > ctx.db_operations

      # Success with string keys
      {:ok, res2, _} =
        SetNameplate.execute(%{"color" => "#123456"}, %{"user_id" => user.id}, ctx)

      assert res2.success == true

      # User not found
      {:error, err, _} =
        SetNameplate.execute(%{}, %{user_id: Ecto.UUID.generate()}, ctx)

      assert err =~ "User not found"
    end

    test "SetPostbitBackground sets postbit background image and opacity" do
      user = create_user()
      ctx = make_ctx()

      assert %{type: "profile/set_postbit_background"} = SetPostbitBackground.schema()
      assert :ok = SetPostbitBackground.validate_config(%{})

      # Success with atom keys
      {:ok, res, u_ctx} =
        SetPostbitBackground.execute(
          %{"opacity" => 0.5},
          %{user_id: user.id, image_url: "https://example.com/postbit.png"},
          ctx
        )

      assert res.success == true
      assert u_ctx.db_operations > ctx.db_operations

      # Success with string keys
      {:ok, res2, _} =
        SetPostbitBackground.execute(
          %{},
          %{"user_id" => user.id, "image_url" => "https://example.com/bg.png"},
          ctx
        )

      assert res2.success == true

      # User not found
      {:error, err, _} =
        SetPostbitBackground.execute(
          %{},
          %{user_id: Ecto.UUID.generate(), image_url: "https://example.com/bg.png"},
          ctx
        )

      assert err =~ "User not found"
    end

    test "SetPostbitStyle updates post and postbit backgrounds and validates opacity" do
      user = create_user()
      ctx = make_ctx()

      assert %{type: "profile/set_postbit_style"} = SetPostbitStyle.schema()

      assert :ok =
               SetPostbitStyle.validate_config(%{
                 "background_opacity" => 0.4,
                 "postbit_opacity" => 0.8
               })

      assert :ok =
               SetPostbitStyle.validate_config(%{
                 "background_opacity" => 1,
                 "postbit_opacity" => "0.5"
               })

      assert :ok = SetPostbitStyle.validate_config(%{})
      assert {:error, _} = SetPostbitStyle.validate_config(%{"background_opacity" => 1.5})
      assert {:error, _} = SetPostbitStyle.validate_config(%{"postbit_opacity" => -0.2})

      # Success with all configs
      {:ok, res, u_ctx} =
        SetPostbitStyle.execute(
          %{
            "background_url" => "https://example.com/post_bg.png",
            "background_opacity" => 0.6,
            "postbit_url" => "https://example.com/postbit_bg.png",
            "postbit_opacity" => 0.7
          },
          %{user_id: user.id},
          ctx
        )

      assert res.success == true
      assert u_ctx.db_operations > ctx.db_operations

      # Success with empty string urls and opacity variations
      {:ok, res2, _} =
        SetPostbitStyle.execute(
          %{
            "background_url" => "",
            "background_opacity" => "0.5",
            "postbit_url" => "",
            "postbit_opacity" => "bad_opacity"
          },
          %{"user_id" => user.id},
          ctx
        )

      assert res2.success == true

      # Non-binary / non-number opacity fallback
      {:ok, res3, _} =
        SetPostbitStyle.execute(
          %{"background_opacity" => :bad, "postbit_opacity" => 1},
          %{user_id: user.id},
          ctx
        )

      assert res3.success == true

      # User not found
      {:error, err, _} =
        SetPostbitStyle.execute(%{}, %{user_id: Ecto.UUID.generate()}, ctx)

      assert err =~ "User not found"
    end

    test "SetProfileBackground updates profile background image" do
      user = create_user()
      ctx = make_ctx()

      assert %{type: "profile/set_profile_background"} = SetProfileBackground.schema()
      assert :ok = SetProfileBackground.validate_config(%{})

      # Success with atom keys
      {:ok, res, u_ctx} =
        SetProfileBackground.execute(
          %{},
          %{user_id: user.id, image_url: "https://example.com/profile_bg.png"},
          ctx
        )

      assert res.success == true
      assert u_ctx.db_operations > ctx.db_operations

      # Success with string keys
      {:ok, res2, _} =
        SetProfileBackground.execute(
          %{},
          %{"user_id" => user.id, "image_url" => "https://example.com/new_bg.png"},
          ctx
        )

      assert res2.success == true

      # User not found
      {:error, err, _} =
        SetProfileBackground.execute(
          %{},
          %{user_id: Ecto.UUID.generate(), image_url: "https://example.com/bg.png"},
          ctx
        )

      assert err =~ "User not found"
    end

    test "SetSignature updates signature field" do
      user = create_user()
      ctx = make_ctx()

      assert %{type: "profile/set_signature"} = SetSignature.schema()
      assert :ok = SetSignature.validate_config(%{})

      # Success with atom keys
      {:ok, res, u_ctx} =
        SetSignature.execute(
          %{},
          %{user_id: user.id, signature: "Sent from my gaming rig"},
          ctx
        )

      assert res.success == true
      assert u_ctx.db_operations > ctx.db_operations

      # Success with string keys
      {:ok, res2, _} =
        SetSignature.execute(
          %{},
          %{"user_id" => user.id, "signature" => "Updated Signature"},
          ctx
        )

      assert res2.success == true

      # User not found
      {:error, err, _} =
        SetSignature.execute(%{}, %{user_id: Ecto.UUID.generate(), signature: "Ghost"}, ctx)

      assert err =~ "User not found"
    end

    test "ShowProfileWidget appends and updates widgets and validates config" do
      user = create_user()
      ctx = make_ctx()

      assert %{type: "profile/show_profile_widget"} = ShowProfileWidget.schema()

      assert :ok =
               ShowProfileWidget.validate_config(%{
                 "widget_type" => "stats",
                 "position" => "sidebar"
               })

      assert :ok =
               ShowProfileWidget.validate_config(%{
                 "widget_type" => "inventory",
                 "position" => "below_avatar"
               })

      assert :ok =
               ShowProfileWidget.validate_config(%{
                 "widget_type" => "badges",
                 "position" => "below_posts"
               })

      assert {:error, _} = ShowProfileWidget.validate_config(%{"widget_type" => "invalid"})
      assert {:error, _} = ShowProfileWidget.validate_config(%{"position" => "invalid"})

      # Append widget
      {:ok, res1, u_ctx} =
        ShowProfileWidget.execute(
          %{"widget_type" => "stats", "position" => "sidebar"},
          %{user_id: user.id, widget_data: %{"show_xp" => true}},
          ctx
        )

      assert res1.success == true
      assert u_ctx.db_operations > ctx.db_operations

      # Replace existing widget (same type + position) and string keys
      {:ok, res2, _} =
        ShowProfileWidget.execute(
          %{"widget_type" => "stats", "position" => "sidebar"},
          %{"user_id" => user.id, "widget_data" => %{"show_xp" => false}},
          ctx
        )

      assert res2.success == true

      # User not found
      {:error, err, _} =
        ShowProfileWidget.execute(%{}, %{user_id: Ecto.UUID.generate()}, ctx)

      assert err =~ "User not found"
    end
  end
end
