defmodule ForgeNexus.Plugins.NodesDataActionAndExecutionTest do
  use ForgeNexus.DataCase, async: false

  alias ForgeNexus.{Accounts, Repo}
  alias ForgeNexus.Accounts.User
  alias ForgeNexus.Plugins.{Flow, FlowEdge, FlowExecution, FlowNode, FlowRateLimit}
  alias ForgeNexus.Plugins.Engine.{Context, Executor, Sandbox, SandboxError}
  alias ForgeNexus.Plugins.Nodes.Action.{AwardPoints, SetCustomTitle}
  alias ForgeNexus.Plugins.Nodes.Data.{GetUserData, SetUserData, GetUserField, SetUserField}

  defp create_user(attrs \\ %{}) do
    unique_suffix = System.unique_integer([:positive])

    defaults = %{
      username: "flow_user_#{unique_suffix}",
      email: "flow_user_#{unique_suffix}@example.com",
      password: "SecurePass!987654#Alpha",
      password_confirmation: "SecurePass!987654#Alpha"
    }

    {:ok, user} =
      defaults
      |> Map.merge(Enum.into(attrs, %{}))
      |> Accounts.register_user()

    user
  end

  defp create_test_flow(user, attrs \\ %{}) do
    unique_suffix = System.unique_integer([:positive])

    defaults = %{
      name: "Test Flow #{unique_suffix}",
      slug: "test-flow-#{unique_suffix}",
      description: "Flow for executor tests",
      trigger_type: "manual",
      status: "active",
      created_by_id: user.id
    }

    %Flow{}
    |> Flow.changeset(Map.merge(defaults, Enum.into(attrs, %{})))
    |> Repo.insert!()
  end

  describe "Engine.Sandbox" do
    test "enforces node, db, http, loop, timeout, and rate limits" do
      ctx = %Context{
        nodes_executed: 200,
        max_nodes: 200,
        db_operations: 50,
        max_db_ops: 50,
        http_requests: 5,
        max_http_requests: 5,
        loop_iterations: 1000,
        max_loop_iterations: 1000,
        started_at: DateTime.utc_now() |> DateTime.add(-35, :second),
        timeout_ms: 30_000
      }

      assert_raise SandboxError, ~r/Node execution limit reached/, fn ->
        Sandbox.check_node_limit!(ctx)
      end

      assert_raise SandboxError, ~r/Database operation limit reached/, fn ->
        Sandbox.check_db_limit!(ctx)
      end

      assert_raise SandboxError, ~r/HTTP request limit reached/, fn ->
        Sandbox.check_http_limit!(ctx)
      end

      assert_raise SandboxError, ~r/Loop iteration limit reached/, fn ->
        Sandbox.check_loop_limit!(ctx)
      end

      assert_raise SandboxError, ~r/Flow execution timed out/, fn ->
        Sandbox.check_timeout!(ctx)
      end

      # Context increments
      normal_ctx = %Context{started_at: DateTime.utc_now(), timeout_ms: 10_000}
      assert :ok = Sandbox.check_node_limit!(normal_ctx)
      assert :ok = Sandbox.check_db_limit!(normal_ctx)
      assert :ok = Sandbox.check_http_limit!(normal_ctx)
      assert :ok = Sandbox.check_loop_limit!(normal_ctx)
      assert :ok = Sandbox.check_timeout!(normal_ctx)

      inc_ctx =
        normal_ctx
        |> Sandbox.increment_nodes()
        |> Sandbox.increment_db_ops()
        |> Sandbox.increment_http_requests()
        |> Sandbox.increment_loop_iterations()

      assert inc_ctx.nodes_executed == 1
      assert inc_ctx.db_operations == 1
      assert inc_ctx.http_requests == 1
      assert inc_ctx.loop_iterations == 1

      # Rate limiting
      user = create_user()
      flow = create_test_flow(user)
      assert :ok = Sandbox.check_rate_limit!(flow.id)
      assert :ok = Sandbox.check_rate_limit!(flow.id)

      # Trigger rate limit exceeded exception
      limit_record = Repo.get_by!(FlowRateLimit, flow_id: flow.id)
      Ecto.Changeset.change(limit_record, %{execution_count: 100}) |> Repo.update!()

      assert_raise SandboxError, ~r/Rate limit exceeded/, fn ->
        Sandbox.check_rate_limit!(flow.id)
      end
    end
  end

  describe "Data Nodes (GetUserData, SetUserData, GetUserField, SetUserField)" do
    test "GetUserData and SetUserData persist and read scoped flow data" do
      user = create_user()
      flow = create_test_flow(user)
      ctx = %Context{flow_id: flow.id, started_at: DateTime.utc_now()}

      # Set user data
      assert {:ok, %{saved: true}, new_ctx} =
               SetUserData.execute(
                 %{"key" => "theme_preference"},
                 %{"user_id" => user.id, "value" => "dark_mode"},
                 ctx
               )

      assert new_ctx.db_operations >= 1

      # Get user data
      assert {:ok, %{value: value}, _} =
               GetUserData.execute(%{"key" => "theme_preference"}, %{"user_id" => user.id}, ctx)

      assert value == %{"_value" => "dark_mode"}

      # Nonexistent key returns nil
      assert {:ok, %{value: nil}, _} =
               GetUserData.execute(%{"key" => "nonexistent"}, %{"user_id" => user.id}, ctx)

      # Validate configs and schemas
      assert :ok = SetUserData.validate_config(%{"key" => "k"})
      assert {:error, _} = SetUserData.validate_config(%{})
      assert is_map(SetUserData.schema())

      assert :ok = GetUserData.validate_config(%{"key" => "k"})
      assert {:error, _} = GetUserData.validate_config(%{})
      assert is_map(GetUserData.schema())
    end

    test "GetUserField and SetUserField read and write allowed fields on user model" do
      user = create_user()
      Ecto.Changeset.change(user, %{custom_title: "Master Artisan"}) |> Repo.update!()
      ctx = %Context{started_at: DateTime.utc_now()}

      # Read allowed fields
      assert {:ok, %{value: "Master Artisan"}, _} =
               GetUserField.execute(%{"field" => "custom_title"}, %{"user_id" => user.id}, ctx)

      assert {:ok, %{value: 0}, _} =
               GetUserField.execute(%{"field" => "post_count"}, %{"user_id" => user.id}, ctx)

      # Read disallowed field
      assert {:error, "Field 'password_hash' is not in the allowed list", _} =
               GetUserField.execute(%{"field" => "password_hash"}, %{"user_id" => user.id}, ctx)

      # Read non-existent user
      assert {:error, "User not found: " <> _, _} =
               GetUserField.execute(
                 %{"field" => "custom_title"},
                 %{"user_id" => Ecto.UUID.generate()},
                 ctx
               )

      # Write allowed field
      assert {:ok, %{updated: true}, _} =
               SetUserField.execute(
                 %{"field" => "custom_title"},
                 %{"user_id" => user.id, "value" => "Grandmaster"},
                 ctx
               )

      assert Repo.get!(User, user.id).custom_title == "Grandmaster"

      # Write disallowed field
      assert {:error, "Field 'email' is not writable" <> _, _} =
               SetUserField.execute(
                 %{"field" => "email"},
                 %{"user_id" => user.id, "value" => "hacked@example.com"},
                 ctx
               )

      # Write non-existent user
      assert {:error, "User not found: " <> _, _} =
               SetUserField.execute(
                 %{"field" => "custom_title"},
                 %{"user_id" => Ecto.UUID.generate(), "value" => "X"},
                 ctx
               )

      # Validate configs and schemas
      assert :ok = GetUserField.validate_config(%{"field" => "custom_title"})
      assert {:error, _} = GetUserField.validate_config(%{"field" => "invalid_field"})
      assert is_map(GetUserField.schema())

      assert :ok = SetUserField.validate_config(%{"field" => "custom_title"})
      assert {:error, _} = SetUserField.validate_config(%{"field" => "invalid_field"})
      assert is_map(SetUserField.schema())
    end
  end

  describe "Action Nodes (AwardPoints, SetCustomTitle)" do
    test "AwardPoints atomically adjusts points and handles missing user" do
      user = create_user()
      ctx = %Context{started_at: DateTime.utc_now()}

      assert {:ok, %{awarded: true, points: 50}, new_ctx} =
               AwardPoints.execute(%{}, %{"user_id" => user.id, "points" => 50}, ctx)

      assert new_ctx.db_operations >= 1
      assert Repo.get!(User, user.id).reputation == 50

      # Missing user error
      assert {:error, "User not found: " <> _, _} =
               AwardPoints.execute(%{}, %{"user_id" => Ecto.UUID.generate(), "points" => 10}, ctx)

      assert :ok = AwardPoints.validate_config(%{})
      assert is_map(AwardPoints.schema())
    end

    test "SetCustomTitle updates title and handles missing user" do
      user = create_user()
      ctx = %Context{started_at: DateTime.utc_now()}

      assert {:ok, %{updated: true}, _} =
               SetCustomTitle.execute(%{}, %{"user_id" => user.id, "title" => "Champion"}, ctx)

      assert Repo.get!(User, user.id).custom_title == "Champion"

      assert {:error, "User not found: " <> _, _} =
               SetCustomTitle.execute(
                 %{},
                 %{"user_id" => Ecto.UUID.generate(), "title" => "Champion"},
                 ctx
               )

      assert :ok = SetCustomTitle.validate_config(%{})
      assert is_map(SetCustomTitle.schema())
    end
  end

  describe "Engine.Executor.execute_flow/3" do
    test "executes linear flow, records execution history, and updates flow stats" do
      user = create_user()
      flow = create_test_flow(user)

      # Node 1: Trigger
      trigger_node =
        %FlowNode{}
        |> FlowNode.changeset(%{
          flow_id: flow.id,
          type: "trigger/manual",
          category: "trigger",
          label: "Manual Trigger"
        })
        |> Repo.insert!()

      # Node 2: Contains check
      contains_node =
        %FlowNode{}
        |> FlowNode.changeset(%{
          flow_id: flow.id,
          type: "text/contains",
          category: "text",
          label: "Check Keyword",
          config: %{"case_sensitive" => false}
        })
        |> Repo.insert!()

      # Edge: Trigger -> Contains
      %FlowEdge{}
      |> FlowEdge.changeset(%{
        flow_id: flow.id,
        source_node_id: trigger_node.id,
        target_node_id: contains_node.id,
        source_port: "output",
        target_port: "input"
      })
      |> Repo.insert!()

      trigger_data = %{"text" => "Welcome to ForgeNexus gaming hub", "search" => "forgenexus"}

      assert {:completed, result} = Executor.execute_flow(flow.id, trigger_data, user.id)
      assert result.result == true

      # Verify Flow execution record
      executions = Repo.all(FlowExecution)
      assert length(executions) == 1
      exec = hd(executions)
      assert exec.flow_id == flow.id
      assert exec.status == "completed"
      assert is_integer(exec.duration_ms)
      assert length(exec.node_trace) == 2

      # Verify Flow stats updated
      updated_flow = Repo.get!(Flow, flow.id)
      assert updated_flow.execution_count == 1
      assert updated_flow.last_executed_at != nil
    end

    test "executes branching flow following true and false branch ports" do
      user = create_user()
      flow = create_test_flow(user)

      trigger_node =
        %FlowNode{}
        |> FlowNode.changeset(%{
          flow_id: flow.id,
          type: "trigger/manual",
          category: "trigger",
          label: "Trigger"
        })
        |> Repo.insert!()

      ifelse_node =
        %FlowNode{}
        |> FlowNode.changeset(%{
          flow_id: flow.id,
          type: "logic/if_else",
          category: "logic",
          label: "Score Check",
          config: %{"field" => "triggered_by", "operator" => "neq", "value" => ""}
        })
        |> Repo.insert!()

      true_node =
        %FlowNode{}
        |> FlowNode.changeset(%{
          flow_id: flow.id,
          type: "text/contains",
          category: "text",
          label: "True Path",
          config: %{"case_sensitive" => false}
        })
        |> Repo.insert!()

      false_node =
        %FlowNode{}
        |> FlowNode.changeset(%{
          flow_id: flow.id,
          type: "text/contains",
          category: "text",
          label: "False Path",
          config: %{"case_sensitive" => false}
        })
        |> Repo.insert!()

      # Edges
      %FlowEdge{}
      |> FlowEdge.changeset(%{
        flow_id: flow.id,
        source_node_id: trigger_node.id,
        target_node_id: ifelse_node.id,
        source_port: "output",
        target_port: "input"
      })
      |> Repo.insert!()

      %FlowEdge{}
      |> FlowEdge.changeset(%{
        flow_id: flow.id,
        source_node_id: ifelse_node.id,
        target_node_id: true_node.id,
        source_port: "true",
        target_port: "input"
      })
      |> Repo.insert!()

      %FlowEdge{}
      |> FlowEdge.changeset(%{
        flow_id: flow.id,
        source_node_id: ifelse_node.id,
        target_node_id: false_node.id,
        source_port: "false",
        target_port: "input"
      })
      |> Repo.insert!()

      # Execute with triggered_by = user.id -> follows 'true' branch
      assert {:completed, result_true} =
               Executor.execute_flow(
                 flow.id,
                 %{},
                 user.id
               )

      assert is_map(result_true)
      assert Map.has_key?(result_true, :result)

      # Execute with triggered_by = nil -> follows 'false' branch
      assert {:completed, result_false} =
               Executor.execute_flow(
                 flow.id,
                 %{},
                 nil
               )

      assert is_map(result_false)
      assert Map.has_key?(result_false, :result)
    end

    test "handles missing trigger node and broken edge reference gracefully" do
      user = create_user()

      # Flow without trigger node
      empty_flow = create_test_flow(user)

      assert {:failed, %{error: "No trigger node found in flow"}} =
               Executor.execute_flow(empty_flow.id, %{})

      # Directly test run_graph with an edge referencing a missing node in nodes_map
      trigger_node = %FlowNode{
        id: Ecto.UUID.generate(),
        type: "trigger/manual",
        category: "trigger",
        config: %{}
      }

      fake_target_id = Ecto.UUID.generate()

      broken_edge = %FlowEdge{
        source_node_id: trigger_node.id,
        target_node_id: fake_target_id,
        source_port: "output"
      }

      ctx = %Context{
        flow_id: Ecto.UUID.generate(),
        trigger_data: %{},
        started_at: DateTime.utc_now()
      }

      nodes_map = %{trigger_node.id => trigger_node}
      edges_by_source = %{trigger_node.id => [broken_edge]}

      assert {:error, "Edge references missing node: " <> _, _} =
               Executor.run_graph(trigger_node, nodes_map, edges_by_source, ctx)
    end
  end
end
