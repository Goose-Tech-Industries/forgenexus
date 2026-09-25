defmodule ForgeNexus.Plugins.PluginsSchemasTest do
  use ForgeNexus.DataCase, async: true

  alias ForgeNexus.Plugins.{
    CustomDataColumn,
    CustomDataRow,
    CustomDataTable,
    Flow,
    FlowEdge,
    FlowExecution,
    FlowGlobalStore,
    FlowNode,
    FlowRateLimit,
    JsPlugin,
    JsPluginExecution,
    JsPluginRateLimit,
    PluginPage,
    PluginWidget,
    SlashCommand
  }

  describe "CustomDataTable" do
    @uid Ecto.UUID.generate()

    test "valid changeset and scope inclusions" do
      for scope <- ~w(global per_user per_thread per_forum) do
        cs =
          CustomDataTable.changeset(%CustomDataTable{}, %{
            name: "Inventory Records",
            slug: "inventory-records",
            created_by_id: @uid,
            scope: scope,
            max_rows: 5000
          })

        assert cs.valid?
        assert get_field(cs, :scope) == scope
      end

      req_cs = CustomDataTable.changeset(%CustomDataTable{}, %{})
      refute req_cs.valid?
      assert "can't be blank" in errors_on(req_cs).name
      assert "can't be blank" in errors_on(req_cs).slug
      assert "can't be blank" in errors_on(req_cs).created_by_id

      bad_scope_cs =
        CustomDataTable.changeset(%CustomDataTable{}, %{
          name: "Table",
          slug: "table",
          created_by_id: @uid,
          scope: "cluster"
        })

      refute bad_scope_cs.valid?
      assert "is invalid" in errors_on(bad_scope_cs).scope
    end
  end

  describe "CustomDataColumn" do
    @tid Ecto.UUID.generate()

    test "valid changeset and data_type inclusions" do
      for dt <- ~w(string integer float boolean json datetime) do
        cs =
          CustomDataColumn.changeset(%CustomDataColumn{}, %{
            table_id: @tid,
            name: "Field #{dt}",
            slug: "field_#{dt}",
            data_type: dt
          })

        assert cs.valid?
        assert get_field(cs, :data_type) == dt
      end

      req_cs = CustomDataColumn.changeset(%CustomDataColumn{}, %{})
      refute req_cs.valid?
      assert "can't be blank" in errors_on(req_cs).table_id
      assert "can't be blank" in errors_on(req_cs).name
      assert "can't be blank" in errors_on(req_cs).slug
      assert "can't be blank" in errors_on(req_cs).data_type

      bad_type_cs =
        CustomDataColumn.changeset(%CustomDataColumn{}, %{
          table_id: @tid,
          name: "Field",
          slug: "field",
          data_type: "blob"
        })

      refute bad_type_cs.valid?
      assert "is invalid" in errors_on(bad_type_cs).data_type
    end
  end

  describe "CustomDataRow" do
    @tid Ecto.UUID.generate()

    test "valid changeset and update_changeset" do
      cs =
        CustomDataRow.changeset(%CustomDataRow{}, %{
          table_id: @tid,
          data: %{"score" => 100}
        })

      assert cs.valid?
      assert get_field(cs, :data) == %{"score" => 100}

      up_cs = CustomDataRow.update_changeset(cs, %{data: %{"score" => 120}})
      assert up_cs.valid?
      assert get_field(up_cs, :data) == %{"score" => 120}

      req_cs = CustomDataRow.changeset(%CustomDataRow{}, %{data: nil})
      refute req_cs.valid?
      assert "can't be blank" in errors_on(req_cs).table_id
      assert "can't be blank" in errors_on(req_cs).data

      req_up_cs = CustomDataRow.update_changeset(%CustomDataRow{}, %{data: nil})
      refute req_up_cs.valid?
      assert "can't be blank" in errors_on(req_up_cs).data
    end
  end

  describe "Flow" do
    @uid Ecto.UUID.generate()

    test "valid changeset, status_changeset, and execution_changeset" do
      cs =
        Flow.changeset(%Flow{}, %{
          name: "Welcome Flow",
          slug: "welcome-flow",
          trigger_type: "on_post_created",
          created_by_id: @uid,
          status: "active",
          tier: "nocode"
        })

      assert cs.valid?
      assert get_field(cs, :name) == "Welcome Flow"

      st_cs = Flow.status_changeset(cs, %{status: "disabled"})
      assert st_cs.valid?
      assert get_field(st_cs, :status) == "disabled"

      now = ~U[2026-03-01 12:00:00Z]
      ex_cs = Flow.execution_changeset(cs, %{last_executed_at: now, execution_count: 5})
      assert ex_cs.valid?
      assert get_field(ex_cs, :execution_count) == 5

      req_cs = Flow.changeset(%Flow{}, %{})
      refute req_cs.valid?
      assert "can't be blank" in errors_on(req_cs).name
      assert "can't be blank" in errors_on(req_cs).slug
      assert "can't be blank" in errors_on(req_cs).trigger_type
      assert "can't be blank" in errors_on(req_cs).created_by_id
    end
  end

  describe "FlowEdge" do
    @fid Ecto.UUID.generate()
    @nid1 Ecto.UUID.generate()
    @nid2 Ecto.UUID.generate()

    test "valid changeset" do
      cs =
        FlowEdge.changeset(%FlowEdge{}, %{
          flow_id: @fid,
          source_node_id: @nid1,
          target_node_id: @nid2,
          condition: "score > 50"
        })

      assert cs.valid?

      req_cs = FlowEdge.changeset(%FlowEdge{}, %{})
      refute req_cs.valid?
      assert "can't be blank" in errors_on(req_cs).flow_id
      assert "can't be blank" in errors_on(req_cs).source_node_id
      assert "can't be blank" in errors_on(req_cs).target_node_id
    end
  end

  describe "FlowExecution" do
    @fid Ecto.UUID.generate()

    test "valid changeset and complete_changeset" do
      now = ~U[2026-03-01 12:00:00Z]

      cs =
        FlowExecution.changeset(%FlowExecution{}, %{
          flow_id: @fid,
          trigger_type: "event",
          started_at: now,
          status: "running"
        })

      assert cs.valid?

      fin = ~U[2026-03-01 12:00:02Z]

      comp_cs =
        FlowExecution.complete_changeset(cs, %{
          status: "completed",
          finished_at: fin,
          duration_ms: 2000
        })

      assert comp_cs.valid?
      assert get_field(comp_cs, :status) == "completed"

      req_cs = FlowExecution.changeset(%FlowExecution{}, %{})
      refute req_cs.valid?
      assert "can't be blank" in errors_on(req_cs).flow_id
      assert "can't be blank" in errors_on(req_cs).trigger_type
      assert "can't be blank" in errors_on(req_cs).started_at
    end
  end

  describe "FlowGlobalStore" do
    @fid Ecto.UUID.generate()

    test "valid changeset" do
      cs =
        FlowGlobalStore.changeset(%FlowGlobalStore{}, %{
          flow_id: @fid,
          key: "daily_count",
          value: %{"count" => 42}
        })

      assert cs.valid?
      assert get_field(cs, :key) == "daily_count"

      req_cs = FlowGlobalStore.changeset(%FlowGlobalStore{}, %{})
      refute req_cs.valid?
      assert "can't be blank" in errors_on(req_cs).flow_id
      assert "can't be blank" in errors_on(req_cs).key
    end
  end

  describe "FlowNode" do
    @fid Ecto.UUID.generate()

    test "valid changeset" do
      cs =
        FlowNode.changeset(%FlowNode{}, %{
          flow_id: @fid,
          type: "action/http_request",
          category: "action",
          label: "Send Webhook"
        })

      assert cs.valid?
      assert get_field(cs, :label) == "Send Webhook"

      req_cs = FlowNode.changeset(%FlowNode{}, %{})
      refute req_cs.valid?
      assert "can't be blank" in errors_on(req_cs).flow_id
      assert "can't be blank" in errors_on(req_cs).type
      assert "can't be blank" in errors_on(req_cs).category
    end
  end

  describe "FlowRateLimit" do
    @fid Ecto.UUID.generate()

    test "valid changeset" do
      now = ~U[2026-03-01 12:00:00Z]

      cs =
        FlowRateLimit.changeset(%FlowRateLimit{}, %{
          flow_id: @fid,
          window_start: now,
          execution_count: 3
        })

      assert cs.valid?

      req_cs = FlowRateLimit.changeset(%FlowRateLimit{}, %{})
      refute req_cs.valid?
      assert "can't be blank" in errors_on(req_cs).flow_id
      assert "can't be blank" in errors_on(req_cs).window_start
    end
  end

  describe "JsPlugin" do
    @uid Ecto.UUID.generate()

    test "valid changeset, status_changeset, execution_changeset, settings_changeset" do
      cs =
        JsPlugin.changeset(%JsPlugin{}, %{
          name: "Bad Word Filter",
          slug: "bad-word-filter",
          created_by_id: @uid,
          code: "function run() { return true; }",
          status: "draft"
        })

      assert cs.valid?
      assert get_field(cs, :slug) == "bad-word-filter"

      st_cs = JsPlugin.status_changeset(cs, %{status: "active"})
      assert st_cs.valid?
      assert get_field(st_cs, :status) == "active"

      now = ~U[2026-03-01 12:00:00Z]
      ex_cs = JsPlugin.execution_changeset(cs, %{last_executed_at: now, execution_count: 10})
      assert ex_cs.valid?
      assert get_field(ex_cs, :execution_count) == 10

      set_cs = JsPlugin.settings_changeset(cs, %{settings: %{"strict_mode" => true}})
      assert set_cs.valid?
      assert get_field(set_cs, :settings) == %{"strict_mode" => true}

      req_cs = JsPlugin.changeset(%JsPlugin{}, %{})
      refute req_cs.valid?
      assert "can't be blank" in errors_on(req_cs).name
      assert "can't be blank" in errors_on(req_cs).slug
      assert "can't be blank" in errors_on(req_cs).created_by_id
    end
  end

  describe "JsPluginExecution" do
    @pid Ecto.UUID.generate()

    test "valid changeset and complete_changeset" do
      now = ~U[2026-03-01 12:00:00Z]

      cs =
        JsPluginExecution.changeset(%JsPluginExecution{}, %{
          js_plugin_id: @pid,
          started_at: now,
          status: "running"
        })

      assert cs.valid?

      comp_cs =
        JsPluginExecution.complete_changeset(cs, %{
          status: "completed",
          finished_at: now,
          duration_ms: 15
        })

      assert comp_cs.valid?

      req_cs = JsPluginExecution.changeset(%JsPluginExecution{}, %{})
      refute req_cs.valid?
      assert "can't be blank" in errors_on(req_cs).js_plugin_id
      assert "can't be blank" in errors_on(req_cs).started_at
    end
  end

  describe "JsPluginRateLimit" do
    @pid Ecto.UUID.generate()

    test "valid changeset" do
      now = ~U[2026-03-01 12:00:00Z]

      cs =
        JsPluginRateLimit.changeset(%JsPluginRateLimit{}, %{
          js_plugin_id: @pid,
          window_start: now,
          execution_count: 1
        })

      assert cs.valid?

      req_cs = JsPluginRateLimit.changeset(%JsPluginRateLimit{}, %{})
      refute req_cs.valid?
      assert "can't be blank" in errors_on(req_cs).js_plugin_id
      assert "can't be blank" in errors_on(req_cs).window_start
    end
  end

  describe "PluginPage" do
    @fid Ecto.UUID.generate()

    test "valid changeset" do
      cs =
        PluginPage.changeset(%PluginPage{}, %{
          flow_id: @fid,
          slug: "leaderboard",
          title: "Community Leaderboard",
          is_published: true
        })

      assert cs.valid?
      assert get_field(cs, :title) == "Community Leaderboard"

      req_cs = PluginPage.changeset(%PluginPage{}, %{})
      refute req_cs.valid?
      assert "can't be blank" in errors_on(req_cs).flow_id
      assert "can't be blank" in errors_on(req_cs).slug
      assert "can't be blank" in errors_on(req_cs).title
    end
  end

  describe "PluginWidget" do
    @fid Ecto.UUID.generate()

    test "valid changeset and placement inclusions" do
      for placement <- ~w(profile_sidebar profile_header post_footer post_header thread_sidebar) do
        cs =
          PluginWidget.changeset(%PluginWidget{}, %{
            flow_id: @fid,
            placement: placement,
            priority: 5
          })

        assert cs.valid?
        assert get_field(cs, :placement) == placement
      end

      req_cs = PluginWidget.changeset(%PluginWidget{}, %{})
      refute req_cs.valid?
      assert "can't be blank" in errors_on(req_cs).flow_id
      assert "can't be blank" in errors_on(req_cs).placement

      bad_placement_cs =
        PluginWidget.changeset(%PluginWidget{}, %{
          flow_id: @fid,
          placement: "footer_banner"
        })

      refute bad_placement_cs.valid?
      assert "is invalid" in errors_on(bad_placement_cs).placement
    end
  end

  describe "SlashCommand" do
    test "valid changeset and formatting" do
      for perm <- ~w(everyone member moderator admin) do
        for resp <- ~w(channel ephemeral dm) do
          cs =
            SlashCommand.changeset(%SlashCommand{}, %{
              name: "roll-dice",
              permission_level: perm,
              response_type: resp
            })

          assert cs.valid?
          assert get_field(cs, :permission_level) == perm
          assert get_field(cs, :response_type) == resp
        end
      end

      req_cs = SlashCommand.changeset(%SlashCommand{}, %{})
      refute req_cs.valid?
      assert "can't be blank" in errors_on(req_cs).name

      bad_name_cs = SlashCommand.changeset(%SlashCommand{}, %{name: "123_invalid"})
      refute bad_name_cs.valid?
      assert "must be lowercase alphanumeric, 1-32 chars" in errors_on(bad_name_cs).name
    end
  end
end
