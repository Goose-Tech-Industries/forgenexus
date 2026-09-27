defmodule ForgeNexus.Plugins.NodesAnalyticsDataIntegrationSchedulingUiTest do
  use ForgeNexus.DataCase, async: false

  alias ForgeNexus.Plugins.Engine.Context

  # Analytics (8)
  alias ForgeNexus.Plugins.Nodes.Analytics.{
    ComparePeriods,
    DetectChurnRisk,
    DetectTrending,
    ExportAnalytics,
    GetContentMetrics,
    GetEngagementScore,
    GetGrowthMetrics,
    GetUserActivity
  }

  # Data (10)
  alias ForgeNexus.Plugins.Nodes.Data.{
    DeleteRow,
    GetGlobalData,
    GetUserData,
    GetUserField,
    InsertRow,
    QueryTable,
    SetGlobalData,
    SetUserData,
    SetUserField,
    UpdateRow
  }

  # Integration (4)
  alias ForgeNexus.Plugins.Nodes.Integration.{
    EmailInbound,
    ParseWebhook,
    PostToSocial,
    YoutubeCheck
  }

  # Scheduling (6)
  alias ForgeNexus.Plugins.Nodes.Scheduling.{
    CreateEvent,
    CreateRecurringPost,
    DoubleXpEvent,
    HolidayTheme,
    RotateFeatured,
    SendReminder
  }

  # UI (3)
  alias ForgeNexus.Plugins.Nodes.UI.{
    RenderPage,
    RenderPostWidget,
    RenderProfileWidget
  }

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
      max_http_requests: 10,
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
          username: "analytics_user_#{uid}",
          email: "user_#{uid}@analytics.test",
          password: "password123456",
          password_confirmation: "password123456"
        },
        attrs
      )
    )
    |> ForgeNexus.Repo.insert!()
  end

  defp create_forum(attrs \\ %{}) do
    uid = System.unique_integer([:positive])

    cat =
      %ForgeNexus.Forums.Category{}
      |> ForgeNexus.Forums.Category.changeset(%{
        name: "Analytics Cat #{uid}",
        slug: "cat-#{uid}",
        position: 1
      })
      |> ForgeNexus.Repo.insert!()

    %ForgeNexus.Forums.Forum{}
    |> ForgeNexus.Forums.Forum.changeset(
      Map.merge(
        %{
          name: "Analytics Forum #{uid}",
          slug: "analytics-forum-#{uid}",
          category_id: cat.id,
          position: 1
        },
        attrs
      )
    )
    |> ForgeNexus.Repo.insert!()
  end

  defp create_thread(forum, user, attrs \\ %{}) do
    uid = System.unique_integer([:positive])

    {:ok, thread} =
      ForgeNexus.Forums.create_thread(
        Map.merge(
          %{
            forum_id: forum.id,
            user_id: user.id,
            title: "Analytics Thread #{uid}",
            body: "Analytics thread content #{uid}"
          },
          attrs
        )
      )

    thread
  end

  defp create_post(thread, user, attrs \\ %{}) do
    {:ok, post} =
      ForgeNexus.Forums.create_post(
        Map.merge(
          %{
            thread_id: thread.id,
            user_id: user.id,
            body: "Analytics post content"
          },
          attrs
        )
      )

    post
  end

  defp create_flow(user, attrs \\ %{}) do
    uid = System.unique_integer([:positive])

    defaults = %{
      name: "Analytics Flow #{uid}",
      slug: "analytics-flow-#{uid}",
      trigger_type: "manual",
      status: "active",
      tier: "nocode",
      created_by_id: user.id
    }

    %ForgeNexus.Plugins.Flow{}
    |> ForgeNexus.Plugins.Flow.changeset(Map.merge(defaults, attrs))
    |> ForgeNexus.Repo.insert!()
  end

  defp create_custom_data_table(user, attrs \\ %{}) do
    uid = System.unique_integer([:positive])

    defaults = %{
      name: "Table #{uid}",
      slug: "table-#{uid}",
      scope: "global",
      created_by_id: user.id
    }

    %ForgeNexus.Plugins.CustomDataTable{}
    |> ForgeNexus.Plugins.CustomDataTable.changeset(Map.merge(defaults, attrs))
    |> ForgeNexus.Repo.insert!()
  end

  defp create_custom_data_row(table, data) do
    %ForgeNexus.Plugins.CustomDataRow{}
    |> ForgeNexus.Plugins.CustomDataRow.changeset(%{table_id: table.id, data: data})
    |> ForgeNexus.Repo.insert!()
  end

  # =========================================================================
  # Analytics Nodes (8)
  # =========================================================================

  describe "Analytics nodes" do
    test "ComparePeriods compares metrics and covers to_int and validate_config" do
      user = create_user()
      forum = create_forum()
      thread = create_thread(forum, user)
      _post = create_post(thread, user)
      ctx = make_ctx()

      assert %{type: "analytics/compare_periods"} = ComparePeriods.schema()

      # Config validations
      assert :ok =
               ComparePeriods.validate_config(%{
                 "metric" => "posts",
                 "compare_to" => "previous_period"
               })

      assert :ok =
               ComparePeriods.validate_config(%{
                 "metric" => "threads",
                 "compare_to" => "same_period_last_month"
               })

      assert :ok =
               ComparePeriods.validate_config(%{
                 "metric" => "users",
                 "compare_to" => "previous_period"
               })

      assert :ok =
               ComparePeriods.validate_config(%{
                 "metric" => "active_users",
                 "compare_to" => "previous_period"
               })

      assert {:error, err1} = ComparePeriods.validate_config(%{"metric" => "invalid"})
      assert hd(err1) =~ "metric must be"
      assert {:error, err2} = ComparePeriods.validate_config(%{"compare_to" => "invalid"})
      assert hd(err2) =~ "compare_to must be"

      # Execute posts with integer period
      {:ok, res1, u_ctx} =
        ComparePeriods.execute(%{"metric" => "posts", "period_days" => 30}, %{}, ctx)

      assert is_map(res1)
      assert res1.current >= 1
      assert u_ctx.db_operations > ctx.db_operations

      # Execute threads with float period
      {:ok, res2, _} =
        ComparePeriods.execute(%{"metric" => "threads", "period_days" => 14.5}, %{}, ctx)

      assert is_map(res2)
      assert res2.current >= 1

      # Execute users with string period
      {:ok, res3, _} =
        ComparePeriods.execute(%{"metric" => "users", "period_days" => "7"}, %{}, ctx)

      assert is_map(res3)
      assert res3.current >= 1

      # Execute active_users with invalid binary period (falls back to 0)
      {:ok, res4, _} =
        ComparePeriods.execute(
          %{"metric" => "active_users", "period_days" => "invalid"},
          %{},
          ctx
        )

      assert is_map(res4)

      # Execute with non-binary non-number period (falls back to 0)
      {:ok, res5, _} =
        ComparePeriods.execute(%{"metric" => "posts", "period_days" => nil}, %{}, ctx)

      assert is_map(res5)
    end

    test "DetectChurnRisk identifies inactive users and covers to_int" do
      ctx = make_ctx()

      assert %{type: "analytics/detect_churn_risk"} = DetectChurnRisk.schema()
      assert :ok = DetectChurnRisk.validate_config(%{})

      # Integer configs
      {:ok, res1, u_ctx} =
        DetectChurnRisk.execute(%{"inactive_days" => 14, "min_previous_activity" => 5}, %{}, ctx)

      assert is_list(res1.at_risk_users)
      assert u_ctx.db_operations > ctx.db_operations

      # Float configs
      {:ok, res2, _} =
        DetectChurnRisk.execute(
          %{"inactive_days" => 7.5, "min_previous_activity" => 2.0},
          %{},
          ctx
        )

      assert is_list(res2.at_risk_users)

      # Binary int configs
      {:ok, res3, _} =
        DetectChurnRisk.execute(
          %{"inactive_days" => "10", "min_previous_activity" => "1"},
          %{},
          ctx
        )

      assert is_list(res3.at_risk_users)

      # Invalid binary and other configs
      {:ok, res4, _} =
        DetectChurnRisk.execute(
          %{"inactive_days" => "bad", "min_previous_activity" => nil},
          %{},
          ctx
        )

      assert is_list(res4.at_risk_users)
    end

    test "DetectTrending identifies trending threads and covers to_int" do
      user = create_user()
      forum = create_forum()
      _thread = create_thread(forum, user)
      ctx = make_ctx()

      assert %{type: "analytics/detect_trending"} = DetectTrending.schema()
      assert :ok = DetectTrending.validate_config(%{})

      # Integer configs
      {:ok, res1, u_ctx} =
        DetectTrending.execute(%{"period_hours" => 24, "limit" => 10}, %{}, ctx)

      assert is_list(res1.trending_threads)
      assert u_ctx.db_operations > ctx.db_operations

      # Float configs
      {:ok, res2, _} = DetectTrending.execute(%{"period_hours" => 12.0, "limit" => 5.5}, %{}, ctx)
      assert is_list(res2.trending_threads)

      # Binary int configs
      {:ok, res3, _} = DetectTrending.execute(%{"period_hours" => "48", "limit" => "3"}, %{}, ctx)
      assert is_list(res3.trending_threads)

      # Invalid binary and other configs
      {:ok, res4, _} =
        DetectTrending.execute(%{"period_hours" => "xyz", "limit" => nil}, %{}, ctx)

      assert is_list(res4.trending_threads)
    end

    test "ExportAnalytics exports metrics to json/csv and covers to_int and validate_config" do
      user = create_user()
      forum = create_forum()
      thread = create_thread(forum, user)
      _post = create_post(thread, user)
      ctx = make_ctx()

      assert %{type: "analytics/export_analytics"} = ExportAnalytics.schema()

      # Config validations
      assert :ok =
               ExportAnalytics.validate_config(%{
                 "metrics" => "posts,threads",
                 "format" => "json"
               })

      assert :ok = ExportAnalytics.validate_config(%{"metrics" => "posts", "format" => "csv"})
      assert {:error, _} = ExportAnalytics.validate_config(%{"metrics" => ""})
      assert {:error, _} = ExportAnalytics.validate_config(%{})

      assert {:error, _} =
               ExportAnalytics.validate_config(%{"metrics" => "posts", "format" => "xml"})

      # JSON format with multiple metrics and integer period
      {:ok, res_json, u_ctx} =
        ExportAnalytics.execute(
          %{
            "metrics" => "posts, threads, users, active_users",
            "format" => "json",
            "period_days" => 30
          },
          %{},
          ctx
        )

      assert is_binary(res_json.data)
      assert res_json.row_count == 4
      assert u_ctx.db_operations > ctx.db_operations

      # CSV format with string period
      {:ok, res_csv, _} =
        ExportAnalytics.execute(
          %{"metrics" => "posts, threads", "format" => "csv", "period_days" => "14"},
          %{},
          ctx
        )

      assert res_csv.data =~ "metric,value"
      assert res_csv.row_count == 2

      # Float period
      {:ok, res_float, _} =
        ExportAnalytics.execute(%{"metrics" => "posts", "period_days" => 10.5}, %{}, ctx)

      assert res_float.row_count == 1

      # Invalid binary period and nil period
      {:ok, res_bad, _} =
        ExportAnalytics.execute(%{"metrics" => "posts", "period_days" => "invalid"}, %{}, ctx)

      assert res_bad.row_count == 1

      {:ok, res_nil, _} =
        ExportAnalytics.execute(%{"metrics" => "posts", "period_days" => nil}, %{}, ctx)

      assert res_nil.row_count == 1
    end

    test "GetContentMetrics retrieves engagement metrics for existing and nonexistent threads" do
      user = create_user()
      forum = create_forum()
      thread = create_thread(forum, user)
      _post = create_post(thread, user)
      ctx = make_ctx()

      assert %{type: "analytics/get_content_metrics"} = GetContentMetrics.schema()
      assert :ok = GetContentMetrics.validate_config(%{})

      # Atom keys for thread_id
      {:ok, res_atom, u_ctx} = GetContentMetrics.execute(%{}, %{thread_id: thread.id}, ctx)
      assert is_number(res_atom.views)
      assert is_number(res_atom.replies)
      assert is_number(res_atom.reactions)
      assert is_number(res_atom.unique_participants)
      assert is_float(res_atom.avg_response_time_hours)
      assert u_ctx.db_operations > ctx.db_operations

      # String keys for thread_id
      {:ok, res_str, _} = GetContentMetrics.execute(%{}, %{"thread_id" => thread.id}, ctx)
      assert is_number(res_str.views)

      # Nonexistent thread returns default zeroes
      {:ok, res_none, _} = GetContentMetrics.execute(%{}, %{thread_id: Ecto.UUID.generate()}, ctx)
      assert res_none.views == 0
      assert res_none.replies == 0
    end

    test "GetEngagementScore computes user score and covers to_int" do
      user = create_user()
      ctx = make_ctx()

      assert %{type: "analytics/get_engagement_score"} = GetEngagementScore.schema()
      assert :ok = GetEngagementScore.validate_config(%{})

      # Atom keys and integer period
      {:ok, res1, u_ctx} =
        GetEngagementScore.execute(%{"period_days" => 30}, %{user_id: user.id}, ctx)

      assert is_number(res1.score)
      assert is_map(res1.breakdown)
      assert u_ctx.db_operations > ctx.db_operations

      # String keys and float period
      {:ok, res2, _} =
        GetEngagementScore.execute(%{"period_days" => 14.5}, %{"user_id" => user.id}, ctx)

      assert is_number(res2.score)

      # String int period
      {:ok, res3, _} =
        GetEngagementScore.execute(%{"period_days" => "7"}, %{user_id: user.id}, ctx)

      assert is_number(res3.score)

      # Invalid binary period and nil period
      {:ok, res4, _} =
        GetEngagementScore.execute(%{"period_days" => "bad"}, %{user_id: user.id}, ctx)

      assert is_number(res4.score)

      {:ok, res5, _} =
        GetEngagementScore.execute(%{"period_days" => nil}, %{user_id: user.id}, ctx)

      assert is_number(res5.score)
    end

    test "GetGrowthMetrics retrieves growth metrics and covers to_int" do
      ctx = make_ctx()

      assert %{type: "analytics/get_growth_metrics"} = GetGrowthMetrics.schema()
      assert :ok = GetGrowthMetrics.validate_config(%{})

      # Integer period
      {:ok, res1, u_ctx} = GetGrowthMetrics.execute(%{"period_days" => 30}, %{}, ctx)
      assert is_number(res1.new_users)
      assert is_number(res1.new_threads)
      assert is_number(res1.new_posts)
      assert is_number(res1.active_users)
      assert u_ctx.db_operations > ctx.db_operations

      # Float period
      {:ok, res2, _} = GetGrowthMetrics.execute(%{"period_days" => 14.0}, %{}, ctx)
      assert is_number(res2.new_users)

      # String int period
      {:ok, res3, _} = GetGrowthMetrics.execute(%{"period_days" => "7"}, %{}, ctx)
      assert is_number(res3.new_users)

      # Invalid binary period and nil period
      {:ok, res4, _} = GetGrowthMetrics.execute(%{"period_days" => "bad"}, %{}, ctx)
      assert is_number(res4.new_users)

      {:ok, res5, _} = GetGrowthMetrics.execute(%{"period_days" => nil}, %{}, ctx)
      assert is_number(res5.new_users)
    end

    test "GetUserActivity retrieves user activity metrics and covers to_int" do
      user = create_user()
      ctx = make_ctx()

      assert %{type: "analytics/get_user_activity"} = GetUserActivity.schema()
      assert :ok = GetUserActivity.validate_config(%{})

      # Atom keys and integer period
      {:ok, res1, u_ctx} =
        GetUserActivity.execute(%{"period_days" => 30}, %{user_id: user.id}, ctx)

      assert is_number(res1.posts)
      assert is_number(res1.threads)
      assert is_number(res1.reactions_given)
      assert is_number(res1.reactions_received)
      assert u_ctx.db_operations > ctx.db_operations

      # String keys and float period
      {:ok, res2, _} =
        GetUserActivity.execute(%{"period_days" => 14.5}, %{"user_id" => user.id}, ctx)

      assert is_number(res2.posts)

      # String int period
      {:ok, res3, _} = GetUserActivity.execute(%{"period_days" => "7"}, %{user_id: user.id}, ctx)
      assert is_number(res3.posts)

      # Invalid binary period and nil period
      {:ok, res4, _} =
        GetUserActivity.execute(%{"period_days" => "bad"}, %{user_id: user.id}, ctx)

      assert is_number(res4.posts)

      {:ok, res5, _} = GetUserActivity.execute(%{"period_days" => nil}, %{user_id: user.id}, ctx)
      assert is_number(res5.posts)
    end
  end

  # =========================================================================
  # Data Nodes (10)
  # =========================================================================

  describe "Data nodes" do
    test "GetGlobalData and SetGlobalData manage global key-value store" do
      user = create_user()
      flow = create_flow(user)
      ctx = make_ctx(%{flow_id: flow.id})

      assert %{type: "data/get_global_data"} = GetGlobalData.schema()
      assert %{type: "data/set_global_data"} = SetGlobalData.schema()

      assert :ok = GetGlobalData.validate_config(%{"key" => "counter"})
      assert {:error, _} = GetGlobalData.validate_config(%{})
      assert :ok = SetGlobalData.validate_config(%{"key" => "counter"})
      assert {:error, _} = SetGlobalData.validate_config(%{})

      # Get nonexistent key
      {:ok, res_nil, u_ctx1} = GetGlobalData.execute(%{"key" => "counter"}, %{}, ctx)
      assert res_nil.value == nil
      assert u_ctx1.db_operations > ctx.db_operations

      # Set initial value with non-map (atom keys)
      {:ok, res_set1, u_ctx2} = SetGlobalData.execute(%{"key" => "counter"}, %{value: 42}, ctx)
      assert res_set1.saved == true
      assert u_ctx2.db_operations > ctx.db_operations

      # Get after set
      {:ok, res_val1, _} = GetGlobalData.execute(%{"key" => "counter"}, %{}, ctx)
      assert res_val1.value == %{"_value" => 42}

      # Update existing key with map value (string keys)
      {:ok, res_set2, _} =
        SetGlobalData.execute(%{"key" => "counter"}, %{"value" => %{"count" => 100}}, ctx)

      assert res_set2.saved == true

      # Get after update
      {:ok, res_val2, _} = GetGlobalData.execute(%{"key" => "counter"}, %{}, ctx)
      assert res_val2.value == %{"count" => 100}
    end

    test "GetUserData and SetUserData manage user scoped key-value store" do
      user = create_user()
      flow = create_flow(user)
      ctx = make_ctx(%{flow_id: flow.id})

      assert %{type: "data/get_user_data"} = GetUserData.schema()
      assert %{type: "data/set_user_data"} = SetUserData.schema()

      assert :ok = GetUserData.validate_config(%{"key" => "streak"})
      assert {:error, _} = GetUserData.validate_config(%{})
      assert :ok = SetUserData.validate_config(%{"key" => "streak"})
      assert {:error, _} = SetUserData.validate_config(%{})

      # Get nonexistent key
      {:ok, res_nil, u_ctx1} = GetUserData.execute(%{"key" => "streak"}, %{user_id: user.id}, ctx)
      assert res_nil.value == nil
      assert u_ctx1.db_operations > ctx.db_operations

      # Set initial value with non-map (atom keys)
      {:ok, res_set1, u_ctx2} =
        SetUserData.execute(%{"key" => "streak"}, %{user_id: user.id, value: 5}, ctx)

      assert res_set1.saved == true
      assert u_ctx2.db_operations > ctx.db_operations

      # Get after set with string keys
      {:ok, res_val1, _} = GetUserData.execute(%{"key" => "streak"}, %{"user_id" => user.id}, ctx)
      assert res_val1.value == %{"_value" => 5}

      # Update existing key with map value and string keys
      {:ok, res_set2, _} =
        SetUserData.execute(
          %{"key" => "streak"},
          %{"user_id" => user.id, "value" => %{"days" => 10}},
          ctx
        )

      assert res_set2.saved == true

      # Get after update
      {:ok, res_val2, _} = GetUserData.execute(%{"key" => "streak"}, %{user_id: user.id}, ctx)
      assert res_val2.value == %{"days" => 10}
    end

    test "GetUserField gets allowed user fields and handles errors" do
      user = create_user()

      user =
        Ecto.Changeset.change(user, %{custom_title: "Forum Veteran"}) |> ForgeNexus.Repo.update!()

      ctx = make_ctx()

      assert %{type: "data/get_user_field"} = GetUserField.schema()

      # Config validation
      assert :ok = GetUserField.validate_config(%{"field" => "username"})
      assert :ok = GetUserField.validate_config(%{"field" => "custom_title"})
      assert {:error, _} = GetUserField.validate_config(%{"field" => "password_hash"})

      assert {:error, _} =
               GetUserField.validate_config(%{"field" => "random_nonexistent_field_12345"})

      # Success with atom keys
      {:ok, res_user, u_ctx} =
        GetUserField.execute(%{"field" => "custom_title"}, %{user_id: user.id}, ctx)

      assert res_user.value == "Forum Veteran"
      assert u_ctx.db_operations > ctx.db_operations

      # Success with string keys
      {:ok, res_name, _} =
        GetUserField.execute(%{"field" => "username"}, %{"user_id" => user.id}, ctx)

      assert is_binary(res_name.value)

      # User not found
      {:error, err_none, _} =
        GetUserField.execute(%{"field" => "username"}, %{user_id: Ecto.UUID.generate()}, ctx)

      assert err_none =~ "User not found"

      # Field not allowed
      {:error, err_disallowed, _} =
        GetUserField.execute(%{"field" => "password_hash"}, %{user_id: user.id}, ctx)

      assert err_disallowed =~ "not in the allowed list"

      # ArgumentError rescue (non-existent atom string)
      {:error, err_arg, _} =
        GetUserField.execute(%{"field" => "nonexistent_atom_str_12345"}, %{user_id: user.id}, ctx)

      assert err_arg =~ "not in the allowed list"
    end

    test "SetUserField updates writable fields and handles errors" do
      user = create_user()
      ctx = make_ctx()

      assert %{type: "data/set_user_field"} = SetUserField.schema()

      # Config validation
      assert :ok = SetUserField.validate_config(%{"field" => "custom_title"})
      assert :ok = SetUserField.validate_config(%{"field" => "reputation"})
      assert {:error, _} = SetUserField.validate_config(%{"field" => "username"})

      assert {:error, _} =
               SetUserField.validate_config(%{"field" => "nonexistent_atom_str_54321"})

      # Success custom_title with atom keys
      {:ok, res1, u_ctx} =
        SetUserField.execute(
          %{"field" => "custom_title"},
          %{user_id: user.id, value: "Elite Member"},
          ctx
        )

      assert res1.updated == true
      assert u_ctx.db_operations > ctx.db_operations

      # Success reputation with string keys
      {:ok, res2, _} =
        SetUserField.execute(
          %{"field" => "reputation"},
          %{"user_id" => user.id, "value" => 150},
          ctx
        )

      assert res2.updated == true

      # Field not writable
      {:error, err_unwritable, _} =
        SetUserField.execute(
          %{"field" => "username"},
          %{user_id: user.id, value: "new_name"},
          ctx
        )

      assert err_unwritable =~ "not writable"

      # ArgumentError rescue (non-existent atom string)
      {:error, err_arg, _} =
        SetUserField.execute(
          %{"field" => "nonexistent_atom_str_54321"},
          %{user_id: user.id, value: "x"},
          ctx
        )

      assert err_arg =~ "not writable"

      # User not found
      {:error, err_none, _} =
        SetUserField.execute(
          %{"field" => "custom_title"},
          %{user_id: Ecto.UUID.generate(), value: "x"},
          ctx
        )

      assert err_none =~ "User not found"
    end

    test "InsertRow inserts row into custom data table and handles errors" do
      user = create_user()
      table = create_custom_data_table(user)
      ctx = make_ctx()

      assert %{type: "data/insert_row"} = InsertRow.schema()
      assert :ok = InsertRow.validate_config(%{"table_slug" => table.slug})
      assert {:error, _} = InsertRow.validate_config(%{})

      # Success with string and atom mappings
      config = %{
        "table_slug" => table.slug,
        "column_mappings" => %{"name" => "input_name", "score" => "input_score"}
      }

      {:ok, res1, u_ctx} =
        InsertRow.execute(config, %{"input_name" => "Alpha", :input_score => 100}, ctx)

      assert res1.row["name"] == "Alpha"
      assert res1.row["score"] == 100
      assert is_binary(res1.row_id)
      assert u_ctx.db_operations > ctx.db_operations

      # Table not found
      {:error, err_tbl, _} =
        InsertRow.execute(%{"table_slug" => "nonexistent_table"}, %{}, ctx)

      assert err_tbl =~ "not found"

      # ArgumentError rescue (non-existent atom in column_mappings)
      bad_config = %{
        "table_slug" => table.slug,
        "column_mappings" => %{"name" => "nonexistent_atom_ref_98765"}
      }

      {:error, err_ref, _} = InsertRow.execute(bad_config, %{}, ctx)
      assert err_ref =~ "Invalid input field reference"
    end

    test "UpdateRow updates existing row and handles errors" do
      user = create_user()
      table = create_custom_data_table(user)
      row = create_custom_data_row(table, %{"name" => "Original", "rank" => 1})
      ctx = make_ctx()

      assert %{type: "data/update_row"} = UpdateRow.schema()
      assert :ok = UpdateRow.validate_config(%{})

      # Success with atom keys
      {:ok, res1, u_ctx} =
        UpdateRow.execute(%{}, %{row_id: row.id, data: %{"name" => "Updated"}}, ctx)

      assert res1.updated == true
      assert u_ctx.db_operations > ctx.db_operations

      # Success with string keys
      {:ok, res2, _} =
        UpdateRow.execute(%{}, %{"row_id" => row.id, "data" => %{"rank" => 2}}, ctx)

      assert res2.updated == true

      # Row not found
      {:error, err_none, _} =
        UpdateRow.execute(%{}, %{row_id: Ecto.UUID.generate(), data: %{}}, ctx)

      assert err_none =~ "Row not found"
    end

    test "DeleteRow deletes row from table and handles errors" do
      user = create_user()
      table = create_custom_data_table(user)
      row1 = create_custom_data_row(table, %{"score" => 10})
      row2 = create_custom_data_row(table, %{"score" => 20})
      ctx = make_ctx()

      assert %{type: "data/delete_row"} = DeleteRow.schema()
      assert :ok = DeleteRow.validate_config(%{})

      # Success with atom keys
      {:ok, res1, u_ctx} = DeleteRow.execute(%{}, %{row_id: row1.id}, ctx)
      assert res1.deleted == true
      assert u_ctx.db_operations > ctx.db_operations

      # Success with string keys
      {:ok, res2, _} = DeleteRow.execute(%{}, %{"row_id" => row2.id}, ctx)
      assert res2.deleted == true

      # Row not found
      {:error, err_none, _} = DeleteRow.execute(%{}, %{row_id: Ecto.UUID.generate()}, ctx)
      assert err_none =~ "Row not found"
    end

    test "QueryTable queries rows with ordering, filters and handles errors" do
      user = create_user()
      table = create_custom_data_table(user)
      _row1 = create_custom_data_row(table, %{"team" => "red", "points" => 50})
      _row2 = create_custom_data_row(table, %{"team" => "blue", "points" => 80})
      ctx = make_ctx()

      assert %{type: "data/query_table"} = QueryTable.schema()

      # Config validations
      assert :ok = QueryTable.validate_config(%{"table_slug" => table.slug})
      assert {:error, _} = QueryTable.validate_config(%{})

      # Table not found
      {:error, err_tbl, _} =
        QueryTable.execute(%{"table_slug" => "nonexistent"}, %{}, ctx)

      assert err_tbl =~ "not found"

      # Query order by inserted_at
      {:ok, res_ins, u_ctx} =
        QueryTable.execute(
          %{"table_slug" => table.slug, "order_by" => "inserted_at", "limit" => 10},
          %{},
          ctx
        )

      assert res_ins.count == 2
      assert u_ctx.db_operations > ctx.db_operations

      # Query order by updated_at
      {:ok, res_upd, _} =
        QueryTable.execute(%{"table_slug" => table.slug, "order_by" => "updated_at"}, %{}, ctx)

      assert res_upd.count == 2

      # Query order by fallback
      {:ok, res_other, _} =
        QueryTable.execute(%{"table_slug" => table.slug, "order_by" => "custom"}, %{}, ctx)

      assert res_other.count == 2

      # Query with "eq" filter matching and "unknown" filter
      config_filtered = %{
        "table_slug" => table.slug,
        "filters" => [
          %{"field" => "team", "operator" => "eq", "value" => "red"},
          %{"field" => "team", "operator" => "noop", "value" => "red"}
        ]
      }

      {:ok, res_filter, _} = QueryTable.execute(config_filtered, %{}, ctx)
      assert res_filter.count == 1
      assert hd(res_filter.rows)["team"] == "red"

      # Query with non-list filters
      {:ok, res_nonlist, _} =
        QueryTable.execute(%{"table_slug" => table.slug, "filters" => "not_a_list"}, %{}, ctx)

      assert res_nonlist.count == 2
    end
  end

  # =========================================================================
  # Integration Nodes (4)
  # =========================================================================

  describe "Integration nodes" do
    test "EmailInbound extracts trigger data from inbound webhook" do
      ctx = make_ctx()

      assert %{type: "integration/email_inbound"} = EmailInbound.schema()
      assert :ok = EmailInbound.validate_config(%{})

      prev_level = Logger.level()
      Logger.configure(level: :debug)

      # Trigger data with string keys
      ctx_str = %{
        ctx
        | trigger_data: %{
            "from" => "sender@test.com",
            "subject" => "Feedback",
            "body" => "Hello world",
            "attachments" => ["file1.png"]
          }
      }

      {:ok, res_str, _} = EmailInbound.execute(%{}, %{}, ctx_str)
      assert res_str.from == "sender@test.com"
      assert res_str.subject == "Feedback"
      assert res_str.body == "Hello world"
      assert res_str.attachments == ["file1.png"]

      # Trigger data with atom keys
      ctx_atom = %{
        ctx
        | trigger_data: %{
            from: "alice@test.com",
            subject: "Update",
            body: "Great post!",
            attachments: []
          }
      }

      {:ok, res_atom, _} = EmailInbound.execute(%{}, %{}, ctx_atom)
      assert res_atom.from == "alice@test.com"
      assert res_atom.subject == "Update"

      # Empty trigger data
      ctx_empty = %{ctx | trigger_data: nil}
      {:ok, res_empty, _} = EmailInbound.execute(%{}, %{}, ctx_empty)
      assert res_empty.from == ""
      assert res_empty.subject == ""

      Logger.configure(level: prev_level)
    end

    test "ParseWebhook extracts fields using dot-path mappings and validates config" do
      ctx = make_ctx()

      assert %{type: "integration/parse_webhook"} = ParseWebhook.schema()

      # Config validations
      assert :ok = ParseWebhook.validate_config(%{"mappings" => %{"user" => "data.user"}})

      assert :ok =
               ParseWebhook.validate_config(%{
                 "mappings" => Jason.encode!(%{"user" => "data.user"})
               })

      assert {:error, _} = ParseWebhook.validate_config(%{})
      assert {:error, _} = ParseWebhook.validate_config(%{"mappings" => %{}})
      assert {:error, _} = ParseWebhook.validate_config(%{"mappings" => "invalid_json"})
      assert {:error, _} = ParseWebhook.validate_config(%{"mappings" => Jason.encode!([1, 2, 3])})
      assert {:error, _} = ParseWebhook.validate_config(%{"mappings" => 12345})

      prev_level = Logger.level()
      Logger.configure(level: :debug)

      # Extract with map mappings and nested paths
      payload = %{
        "event" => "order_completed",
        "customer" => %{
          "profile" => %{"name" => "Carol"},
          "id" => "cust_1"
        },
        :direct_key => "direct_val"
      }

      config_map = %{
        "mappings" => %{
          "evt" => "event",
          "name" => "customer.profile.name",
          "direct" => "direct_key",
          "nonexistent_nested" => "customer.profile.name.subfield",
          "invalid_atom_rescue" => "nonexistent_atom_in_path_12345",
          "bad_path" => nil
        }
      }

      {:ok, res_map, _} = ParseWebhook.execute(config_map, %{payload: payload}, ctx)
      assert res_map.extracted["evt"] == "order_completed"
      assert res_map.extracted["name"] == "Carol"
      assert res_map.extracted["direct"] == "direct_val"
      assert res_map.extracted["nonexistent_nested"] == nil
      assert res_map.extracted["invalid_atom_rescue"] == nil
      assert res_map.extracted["bad_path"] == nil

      # Mappings as valid JSON string and string payload key
      json_mappings = Jason.encode!(%{"evt" => "event"})

      {:ok, res_json, _} =
        ParseWebhook.execute(%{"mappings" => json_mappings}, %{"payload" => payload}, ctx)

      assert res_json.extracted["evt"] == "order_completed"

      # Mappings as valid JSON string of non-map (fallback to %{})
      json_nonmap = Jason.encode!(["a", "b"])

      {:ok, res_nonmap, _} =
        ParseWebhook.execute(%{"mappings" => json_nonmap}, %{payload: payload}, ctx)

      assert res_nonmap.extracted == %{}

      # Mappings as invalid JSON string (fallback to %{})
      {:ok, res_bad_json, _} =
        ParseWebhook.execute(%{"mappings" => "not_json"}, %{payload: payload}, ctx)

      assert res_bad_json.extracted == %{}

      # Mappings as non-binary non-map (fallback to %{})
      {:ok, res_other, _} =
        ParseWebhook.execute(%{"mappings" => 999}, %{payload: payload}, ctx)

      assert res_other.extracted == %{}

      Logger.configure(level: prev_level)
    end

    test "PostToSocial sends webhooks to social platforms and handles responses" do
      ctx = make_ctx()

      assert %{type: "integration/post_to_social"} = PostToSocial.schema()

      # Config validations
      assert :ok =
               PostToSocial.validate_config(%{
                 "webhook_url" => "http://test.com",
                 "platform" => "discord"
               })

      assert :ok =
               PostToSocial.validate_config(%{
                 "webhook_url" => "http://test.com",
                 "platform" => "twitter"
               })

      assert :ok =
               PostToSocial.validate_config(%{
                 "webhook_url" => "http://test.com",
                 "platform" => "generic_webhook"
               })

      assert {:error, _} = PostToSocial.validate_config(%{})
      assert {:error, _} = PostToSocial.validate_config(%{"webhook_url" => ""})

      assert {:error, _} =
               PostToSocial.validate_config(%{
                 "webhook_url" => "http://test.com",
                 "platform" => "bad"
               })

      # Missing webhook_url at execution
      {:error, err_missing, _} =
        PostToSocial.execute(%{"webhook_url" => ""}, %{message: "Hi"}, ctx)

      assert err_missing =~ "webhook_url is required"

      # Start TestMockHttpServer
      {server_pid, port} = ForgeNexus.TestMockHttpServer.start()

      on_exit(fn ->
        try do
          Process.exit(server_pid, :shutdown)
        catch
          _, _ -> :ok
        end
      end)

      # Discord platform (200 success)
      {:ok, res_discord, u_ctx} =
        PostToSocial.execute(
          %{"platform" => "discord", "webhook_url" => "http://127.0.0.1:#{port}/webhook/success"},
          %{message: "Discord notification"},
          ctx
        )

      assert res_discord.success == true
      assert u_ctx.http_requests > ctx.http_requests

      # Twitter platform (200 success) with string keys
      {:ok, res_twitter, _} =
        PostToSocial.execute(
          %{"platform" => "twitter", "webhook_url" => "http://127.0.0.1:#{port}/webhook/success"},
          %{"message" => "Tweet text"},
          ctx
        )

      assert res_twitter.success == true

      # Generic webhook platform (200 success)
      {:ok, res_generic, _} =
        PostToSocial.execute(
          %{
            "platform" => "generic_webhook",
            "webhook_url" => "http://127.0.0.1:#{port}/webhook/success"
          },
          %{message: "Generic notification"},
          ctx
        )

      assert res_generic.success == true

      # Server returns 500 error
      {:error, err_500, _} =
        PostToSocial.execute(
          %{"platform" => "discord", "webhook_url" => "http://127.0.0.1:#{port}/webhook/error"},
          %{message: "Fail"},
          ctx
        )

      assert err_500 =~ "Webhook returned status 500"

      # Connection refused
      {:error, err_conn, _} =
        PostToSocial.execute(
          %{"platform" => "discord", "webhook_url" => "http://127.0.0.1:1/refused"},
          %{message: "Fail"},
          ctx
        )

      assert err_conn =~ "HTTP request failed"
    end

    test "YoutubeCheck parses RSS feeds and handles responses" do
      ctx = make_ctx()

      assert %{type: "integration/youtube_check"} = YoutubeCheck.schema()

      # Config validations
      assert :ok =
               YoutubeCheck.validate_config(%{
                 "channel_url" => "https://youtube.com/channel/UC123"
               })

      assert {:error, _} = YoutubeCheck.validate_config(%{})
      assert {:error, _} = YoutubeCheck.validate_config(%{"channel_url" => ""})

      # Missing channel_url at execution
      {:error, err_missing, _} = YoutubeCheck.execute(%{"channel_url" => ""}, %{}, ctx)
      assert err_missing =~ "channel_url is required"

      # Start TestMockHttpServer
      {server_pid, port} = ForgeNexus.TestMockHttpServer.start()

      on_exit(fn ->
        try do
          Process.exit(server_pid, :shutdown)
        catch
          _, _ -> :ok
        end
      end)

      # Successful feed check
      {:ok, res_feed, u_ctx} =
        YoutubeCheck.execute(
          %{"channel_url" => "http://127.0.0.1:#{port}/youtube/feed"},
          %{},
          ctx
        )

      assert res_feed.has_new == true
      assert res_feed.latest_video.title =~ "My Brand New Video"
      assert res_feed.latest_video.url =~ "abcdef"
      assert is_binary(res_feed.latest_video.published_at)
      assert u_ctx.http_requests > ctx.http_requests

      # Empty feed (no videos)
      {:ok, res_empty, _} =
        YoutubeCheck.execute(
          %{"channel_url" => "http://127.0.0.1:#{port}/youtube/empty"},
          %{},
          ctx
        )

      assert res_empty.has_new == false
      assert res_empty.latest_video == %{}

      # 500 error from feed server
      {:error, err_500, _} =
        YoutubeCheck.execute(
          %{"channel_url" => "http://127.0.0.1:#{port}/youtube/error"},
          %{},
          ctx
        )

      assert err_500 =~ "YouTube RSS returned status 500"

      # Connection refused
      {:error, err_conn, _} =
        YoutubeCheck.execute(
          %{"channel_url" => "http://127.0.0.1:1/refused"},
          %{},
          ctx
        )

      assert err_conn =~ "Failed to fetch YouTube RSS"

      # Channel URL path parsing clauses in to_rss_url (execute triggers network failure)
      {:error, _, _} =
        YoutubeCheck.execute(
          %{"channel_url" => "https://www.youtube.com/channel/UC9999/videos"},
          %{},
          ctx
        )

      {:error, _, _} =
        YoutubeCheck.execute(
          %{"channel_url" => "https://www.youtube.com/@creative_handle/featured"},
          %{},
          ctx
        )

      {:error, _, _} =
        YoutubeCheck.execute(
          %{"channel_url" => "UCraw_id"},
          %{},
          ctx
        )
    end
  end

  # =========================================================================
  # Scheduling Nodes (6)
  # =========================================================================

  describe "Scheduling nodes" do
    test "CreateEvent creates event, parses datetime and validates config" do
      user = create_user()
      ctx = make_ctx(%{triggered_by_id: user.id})

      assert %{type: "scheduling/create_event"} = CreateEvent.schema()

      # Config validations
      valid_cfg = %{
        "starts_at" => "2026-10-01T10:00:00Z",
        "ends_at" => "2026-10-01T12:00:00Z",
        "location" => "Virtual Room"
      }

      assert :ok = CreateEvent.validate_config(valid_cfg)
      assert {:error, _} = CreateEvent.validate_config(%{"ends_at" => "2026-10-01T12:00:00Z"})
      assert {:error, _} = CreateEvent.validate_config(%{"starts_at" => ""})
      assert {:error, _} = CreateEvent.validate_config(%{"starts_at" => "2026-10-01T10:00:00Z"})

      assert {:error, _} =
               CreateEvent.validate_config(%{
                 "starts_at" => "2026-10-01T10:00:00Z",
                 "ends_at" => ""
               })

      # Success with atom keys and parse_dt
      {:ok, res1, u_ctx} =
        CreateEvent.execute(
          valid_cfg,
          %{
            name: "Grand Tournament",
            description: "All community members welcome",
            user_id: user.id
          },
          ctx
        )

      assert is_binary(res1.event_id)
      assert res1.success == true
      assert u_ctx.db_operations > ctx.db_operations

      # Success with string keys and created_by_id
      {:ok, res2, _} =
        CreateEvent.execute(
          valid_cfg,
          %{"name" => "LAN Party", "description" => "Bring snacks", "created_by_id" => user.id},
          ctx
        )

      assert res2.success == true

      # Success with atom created_by_id
      {:ok, res_atom_created, _} =
        CreateEvent.execute(
          valid_cfg,
          %{name: "Atom Created", description: "Desc", created_by_id: user.id},
          ctx
        )

      assert res_atom_created.success == true

      # Success with string user_id
      {:ok, res_str_user, _} =
        CreateEvent.execute(
          valid_cfg,
          %{"name" => "String User", "description" => "Desc", "user_id" => user.id},
          ctx
        )

      assert res_str_user.success == true

      # Success falling back to ctx.triggered_by_id
      {:ok, res_ctx_user, _} =
        CreateEvent.execute(
          valid_cfg,
          %{name: "Ctx User", description: "Desc"},
          ctx
        )

      assert res_ctx_user.success == true

      # parse_dt empty, invalid string, and non-string
      cfg_bad_dt = %{"starts_at" => "", "ends_at" => 12345}

      {:error, err_dt, _} =
        CreateEvent.execute(cfg_bad_dt, %{name: "Event", user_id: user.id}, ctx)

      assert err_dt =~ "Failed to create event"

      cfg_invalid_str = %{"starts_at" => "not_a_date", "ends_at" => "not_a_date"}

      {:error, _, _} =
        CreateEvent.execute(cfg_invalid_str, %{name: "Event", user_id: user.id}, ctx)

      # Validation failure on insert (missing title)
      {:error, err_title, _} = CreateEvent.execute(valid_cfg, %{name: nil, user_id: user.id}, ctx)
      assert err_title =~ "Failed to create event"
    end

    test "CreateRecurringPost configures recurring thread and validates config" do
      ctx = make_ctx()

      assert %{type: "scheduling/create_recurring_post"} = CreateRecurringPost.schema()

      # Config validations
      valid_cfg = %{
        "forum_slug" => "general",
        "title_template" => "Weekly Discussion - {{date}}",
        "body_template" => "Share your thoughts this week!",
        "day_of_week" => "monday",
        "time" => "09:00"
      }

      assert :ok = CreateRecurringPost.validate_config(valid_cfg)
      assert {:error, _} = CreateRecurringPost.validate_config(%{valid_cfg | "forum_slug" => ""})
      assert {:error, _} = CreateRecurringPost.validate_config(%{valid_cfg | "forum_slug" => nil})

      assert {:error, _} =
               CreateRecurringPost.validate_config(%{valid_cfg | "title_template" => ""})

      assert {:error, _} =
               CreateRecurringPost.validate_config(%{valid_cfg | "title_template" => nil})

      assert {:error, _} =
               CreateRecurringPost.validate_config(%{valid_cfg | "day_of_week" => "someday"})

      prev_level = Logger.level()
      Logger.configure(level: :debug)

      # Execution saves to flow_global_store
      {:ok, res, u_ctx} = CreateRecurringPost.execute(valid_cfg, %{}, ctx)
      assert res.success == true
      assert u_ctx.db_operations > ctx.db_operations
      assert [entry | _] = u_ctx.flow_global_store["recurring_posts"]
      assert entry.forum_slug == "general"

      Logger.configure(level: prev_level)
    end

    test "DoubleXpEvent activates XP multiplier and covers to_number and validate_config" do
      ctx = make_ctx()

      assert %{type: "scheduling/double_xp_event"} = DoubleXpEvent.schema()

      # Config validations
      assert :ok = DoubleXpEvent.validate_config(%{"duration_hours" => 24})
      assert :ok = DoubleXpEvent.validate_config(%{"duration_hours" => "48"})
      assert {:error, _} = DoubleXpEvent.validate_config(%{})
      assert {:error, _} = DoubleXpEvent.validate_config(%{"duration_hours" => 0})
      assert {:error, _} = DoubleXpEvent.validate_config(%{"duration_hours" => -1})
      assert {:error, _} = DoubleXpEvent.validate_config(%{"duration_hours" => "0"})
      assert {:error, _} = DoubleXpEvent.validate_config(%{"duration_hours" => "invalid"})
      assert {:error, _} = DoubleXpEvent.validate_config(%{"duration_hours" => %{}})

      prev_level = Logger.level()
      Logger.configure(level: :debug)

      # Execution with numbers
      {:ok, res1, u_ctx} =
        DoubleXpEvent.execute(
          %{"multiplier" => 2.0, "duration_hours" => 24, "stat_key" => "xp"},
          %{},
          ctx
        )

      assert res1.success == true
      assert is_binary(res1.ends_at)
      assert u_ctx.flow_global_store["active_xp_event"].multiplier == 2.0
      assert u_ctx.db_operations > ctx.db_operations

      # Execution with binary strings
      {:ok, res2, u_ctx2} =
        DoubleXpEvent.execute(%{"multiplier" => "3.0", "duration_hours" => "12"}, %{}, ctx)

      assert res2.success == true
      assert u_ctx2.flow_global_store["active_xp_event"].multiplier == 3.0

      # to_number invalid binary and other
      {:ok, res3, _} =
        DoubleXpEvent.execute(%{"multiplier" => "invalid", "duration_hours" => nil}, %{}, ctx)

      assert res3.success == true

      Logger.configure(level: prev_level)
    end

    test "HolidayTheme activates themed effects and covers to_number and validate_config" do
      ctx = make_ctx()

      assert %{type: "scheduling/holiday_theme"} = HolidayTheme.schema()

      # Config validations
      assert :ok =
               HolidayTheme.validate_config(%{
                 "theme_name" => "Halloween",
                 "duration_hours" => 24
               })

      assert :ok =
               HolidayTheme.validate_config(%{"theme_name" => "Winter", "duration_hours" => "48"})

      assert {:error, _} = HolidayTheme.validate_config(%{})
      assert {:error, _} = HolidayTheme.validate_config(%{"theme_name" => ""})
      assert {:error, _} = HolidayTheme.validate_config(%{"theme_name" => "Winter"})

      assert {:error, _} =
               HolidayTheme.validate_config(%{"theme_name" => "Winter", "duration_hours" => 0})

      assert {:error, _} =
               HolidayTheme.validate_config(%{"theme_name" => "Winter", "duration_hours" => "0"})

      assert {:error, _} =
               HolidayTheme.validate_config(%{
                 "theme_name" => "Winter",
                 "duration_hours" => "bad"
               })

      assert {:error, _} =
               HolidayTheme.validate_config(%{"theme_name" => "Winter", "duration_hours" => %{}})

      prev_level = Logger.level()
      Logger.configure(level: :debug)

      # Execution with number duration
      {:ok, res1, u_ctx} =
        HolidayTheme.execute(%{"theme_name" => "Halloween", "duration_hours" => 24}, %{}, ctx)

      assert res1.success == true
      assert is_binary(res1.active_until)
      assert u_ctx.flow_global_store["active_theme"].theme_name == "Halloween"
      assert u_ctx.db_operations > ctx.db_operations

      # Execution with binary duration
      {:ok, res2, u_ctx2} =
        HolidayTheme.execute(%{"theme_name" => "Winter", "duration_hours" => "48.5"}, %{}, ctx)

      assert res2.success == true
      assert u_ctx2.flow_global_store["active_theme"].theme_name == "Winter"

      # to_number invalid binary and nil
      {:ok, res3, _} =
        HolidayTheme.execute(%{"theme_name" => "Spooky", "duration_hours" => "invalid"}, %{}, ctx)

      assert res3.success == true

      {:ok, res4, _} =
        HolidayTheme.execute(%{"theme_name" => "Spooky", "duration_hours" => nil}, %{}, ctx)

      assert res4.success == true

      Logger.configure(level: prev_level)
    end

    test "RotateFeatured rotates featured threads by criteria and covers to_int" do
      user = create_user()
      forum = create_forum()

      _t1 =
        create_thread(forum, user, %{title: "Popular Thread", reply_count: 10, view_count: 100})

      _t2 = create_thread(forum, user, %{title: "Newest Thread", reply_count: 2, view_count: 10})
      ctx = make_ctx()

      assert %{type: "scheduling/rotate_featured"} = RotateFeatured.schema()

      # Config validations
      assert :ok =
               RotateFeatured.validate_config(%{
                 "forum_slug" => forum.slug,
                 "criteria" => "newest"
               })

      assert :ok =
               RotateFeatured.validate_config(%{
                 "forum_slug" => forum.slug,
                 "criteria" => "most_replies"
               })

      assert :ok =
               RotateFeatured.validate_config(%{
                 "forum_slug" => forum.slug,
                 "criteria" => "most_views"
               })

      assert :ok =
               RotateFeatured.validate_config(%{
                 "forum_slug" => forum.slug,
                 "criteria" => "random"
               })

      assert {:error, _} = RotateFeatured.validate_config(%{})
      assert {:error, _} = RotateFeatured.validate_config(%{"forum_slug" => ""})

      assert {:error, _} =
               RotateFeatured.validate_config(%{
                 "forum_slug" => forum.slug,
                 "criteria" => "invalid"
               })

      # Forum not found
      {:error, err_none, _} =
        RotateFeatured.execute(%{"forum_slug" => "nonexistent_forum"}, %{}, ctx)

      assert err_none =~ "Forum not found"

      # Rotate with most_replies and integer count
      {:ok, res_replies, u_ctx} =
        RotateFeatured.execute(
          %{"forum_slug" => forum.slug, "criteria" => "most_replies", "count" => 5},
          %{},
          ctx
        )

      assert res_replies.success == true
      assert is_list(res_replies.featured_threads)
      assert u_ctx.db_operations > ctx.db_operations

      # Rotate with most_views and float count
      {:ok, res_views, _} =
        RotateFeatured.execute(
          %{"forum_slug" => forum.slug, "criteria" => "most_views", "count" => 3.5},
          %{},
          ctx
        )

      assert res_views.success == true

      # Rotate with random and string count
      {:ok, res_rnd, _} =
        RotateFeatured.execute(
          %{"forum_slug" => forum.slug, "criteria" => "random", "count" => "2"},
          %{},
          ctx
        )

      assert res_rnd.success == true

      # Rotate with newest / fallback and invalid/nil count
      {:ok, res_newest, _} =
        RotateFeatured.execute(
          %{"forum_slug" => forum.slug, "criteria" => "newest", "count" => "bad"},
          %{},
          ctx
        )

      assert res_newest.success == true

      {:ok, res_nil, _} =
        RotateFeatured.execute(
          %{"forum_slug" => forum.slug, "criteria" => "newest", "count" => nil},
          %{},
          ctx
        )

      assert res_nil.success == true
    end

    test "SendReminder sends notifications to event RSVPs and covers to_number" do
      user = create_user()
      forum = create_forum()

      event =
        %ForgeNexus.Events.Event{}
        |> ForgeNexus.Events.Event.changeset(%{
          title: "Community Meetup",
          starts_at:
            DateTime.utc_now() |> DateTime.add(3600, :second) |> DateTime.truncate(:second),
          ends_at:
            DateTime.utc_now() |> DateTime.add(7200, :second) |> DateTime.truncate(:second),
          forum_id: forum.id,
          created_by_id: user.id
        })
        |> ForgeNexus.Repo.insert!()

      # RSVP "going"
      ForgeNexus.Events.rsvp(event.id, user.id, "going")

      ctx = make_ctx()

      assert %{type: "scheduling/send_reminder"} = SendReminder.schema()
      assert :ok = SendReminder.validate_config(%{})

      # Success with atom keys and integer minutes
      {:ok, res1, u_ctx} =
        SendReminder.execute(%{"minutes_before" => 60}, %{event_id: event.id}, ctx)

      assert res1.success == true
      assert res1.reminders_sent >= 1
      assert u_ctx.db_operations > ctx.db_operations

      # Success with string keys and float minutes
      {:ok, res2, _} =
        SendReminder.execute(%{"minutes_before" => 30.5}, %{"event_id" => event.id}, ctx)

      assert res2.success == true

      # String minutes
      {:ok, res3, _} =
        SendReminder.execute(%{"minutes_before" => "15.0"}, %{event_id: event.id}, ctx)

      assert res3.success == true

      # Invalid binary and nil minutes
      {:ok, res4, _} =
        SendReminder.execute(%{"minutes_before" => "bad"}, %{event_id: event.id}, ctx)

      assert res4.success == true

      {:ok, res5, _} =
        SendReminder.execute(%{"minutes_before" => nil}, %{event_id: event.id}, ctx)

      assert res5.success == true

      # Nonexistent event (rescue _ -> [])
      {:ok, res_none, _} =
        SendReminder.execute(%{}, %{event_id: Ecto.UUID.generate()}, ctx)

      assert res_none.reminders_sent == 0
    end
  end

  # =========================================================================
  # UI Nodes (3)
  # =========================================================================

  describe "UI nodes" do
    test "RenderPage creates and updates plugin pages and validates config" do
      user = create_user()
      flow = create_flow(user)
      ctx = make_ctx(%{flow_id: flow.id})

      assert %{type: "ui/render_page"} = RenderPage.schema()

      # Config validations
      assert :ok = RenderPage.validate_config(%{"slug" => "my-page", "title" => "My Custom Page"})
      assert {:error, _} = RenderPage.validate_config(%{"title" => "My Custom Page"})
      assert {:error, _} = RenderPage.validate_config(%{"slug" => ""})
      assert {:error, _} = RenderPage.validate_config(%{"slug" => "my-page", "title" => ""})
      assert {:error, _} = RenderPage.validate_config(%{})

      config = %{
        "slug" => "rules-page",
        "title" => "Community Rules",
        "template" => %{"layout" => "full", "content" => "Be respectful."}
      }

      # Create new page (existing is nil)
      {:ok, res_create, u_ctx} = RenderPage.execute(config, %{}, ctx)
      assert is_binary(res_create.page_id)
      assert res_create.slug == "rules-page"
      assert u_ctx.db_operations > ctx.db_operations

      # Update existing page (existing found)
      updated_config = %{
        "slug" => "rules-page",
        "title" => "Community Rules (Updated)",
        "template" => %{"layout" => "full", "content" => "Updated rules."}
      }

      {:ok, res_update, _} = RenderPage.execute(updated_config, %{}, ctx)
      assert res_update.page_id == res_create.page_id
    end

    test "RenderPostWidget creates and updates post widgets" do
      user = create_user()
      flow = create_flow(user)
      ctx = make_ctx(%{flow_id: flow.id})

      assert %{type: "ui/render_post_widget"} = RenderPostWidget.schema()
      assert :ok = RenderPostWidget.validate_config(%{})

      config1 = %{
        "placement" => "post_footer",
        "template" => %{"widget" => "tip_jar", "enabled" => true}
      }

      # Create new post widget (existing is nil)
      {:ok, res_create, u_ctx} = RenderPostWidget.execute(config1, %{}, ctx)
      assert is_binary(res_create.widget_id)
      assert u_ctx.db_operations > ctx.db_operations

      # Update existing post widget (existing found)
      config2 = %{
        "placement" => "post_footer",
        "template" => %{"widget" => "tip_jar", "enabled" => false}
      }

      {:ok, res_update, _} = RenderPostWidget.execute(config2, %{}, ctx)
      assert res_update.widget_id == res_create.widget_id
    end

    test "RenderProfileWidget creates and updates profile widgets" do
      user = create_user()
      flow = create_flow(user)
      ctx = make_ctx(%{flow_id: flow.id})

      assert %{type: "ui/render_profile_widget"} = RenderProfileWidget.schema()
      assert :ok = RenderProfileWidget.validate_config(%{})

      config1 = %{
        "placement" => "profile_sidebar",
        "template" => %{"component" => "bio_card"}
      }

      # Create new profile widget (existing is nil)
      {:ok, res_create, u_ctx} = RenderProfileWidget.execute(config1, %{}, ctx)
      assert is_binary(res_create.widget_id)
      assert u_ctx.db_operations > ctx.db_operations

      # Update existing profile widget (existing found)
      config2 = %{
        "placement" => "profile_sidebar",
        "template" => %{"component" => "bio_card_v2"}
      }

      {:ok, res_update, _} = RenderProfileWidget.execute(config2, %{}, ctx)
      assert res_update.widget_id == res_create.widget_id
    end
  end
end
