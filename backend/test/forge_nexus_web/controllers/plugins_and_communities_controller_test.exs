defmodule ForgeNexusWeb.PluginsAndCommunitiesControllerTest do
  use ForgeNexusWeb.ConnCase, async: false

  alias ForgeNexus.{
    Accounts,
    Applications,
    Channels,
    Communities,
    Forums,
    Guardian,
    Plugins,
    Repo,
    Subscriptions
  }

  alias ForgeNexusWeb.{
    ApplicationController,
    DataTableController,
    ForumPermissionController,
    SubscriptionController
  }

  defp fresh_conn(conn) do
    b3 = rem(System.unique_integer([:positive]), 250) + 1
    b4 = rem(System.unique_integer([:positive]), 250) + 1
    %{conn | remote_ip: {10, 0, b3, b4}}
  end

  defp create_user(attrs \\ %{}) do
    unique = System.unique_integer([:positive])

    default_attrs = %{
      username: "pc_u_#{unique}",
      email: "pc_u_#{unique}@example.com",
      password: "ValidPassword123!@#",
      display_name: "PC User #{unique}"
    }

    {:ok, user} = Accounts.register_user(Map.merge(default_attrs, attrs))

    now = DateTime.utc_now() |> DateTime.truncate(:second)
    {:ok, verified} = user |> Ecto.Changeset.change(email_verified_at: now) |> Repo.update()
    verified
  end

  defp create_admin_user(attrs \\ %{}) do
    user = create_user(attrs)

    admin_group =
      case Repo.get_by(Accounts.UserGroup, name: "Administrators") do
        nil ->
          {:ok, g} =
            Accounts.create_group(%{
              name: "Administrators",
              slug: "administrators-#{System.unique_integer([:positive])}",
              is_staff: true,
              color: "#FF0000"
            })

          g

        g ->
          g
      end

    {:ok, _} = Accounts.add_user_to_group(user.id, admin_group.id)
    user
  end

  defp auth_conn(conn, user) do
    {:ok, token, _claims} = Guardian.encode_and_sign(user)

    conn
    |> fresh_conn()
    |> Guardian.Plug.put_current_resource(user)
    |> Guardian.Plug.put_current_token(token)
    |> put_req_header("authorization", "Bearer #{token}")
    |> put_req_cookie("fn_token", token)
  end

  describe "PluginController (No-Code Flows)" do
    test "flows lifecycle: list, create, show, update, activate, deactivate, execute, delete", %{
      conn: conn
    } do
      admin = create_admin_user()
      admin_conn = auth_conn(conn, admin)

      # 1. list flows (initially empty or existing)
      conn_res = get(admin_conn, ~p"/api/admin/plugins/flows")
      assert %{"flows" => flows} = json_response(conn_res, 200)
      assert is_list(flows)

      # 2. create flow with trigger node and action node
      flow_params = %{
        "flow" => %{
          "name" => "Auto Welcome Flow",
          "description" => "Welcomes users",
          "trigger_type" => "manual",
          "nodes" => [
            %{
              "id" => "node-1",
              "type" => "trigger/manual",
              "category" => "trigger",
              "label" => "Manual Trigger",
              "position_x" => 10.0,
              "position_y" => 20.0
            },
            %{
              "id" => "node-2",
              "type" => "action_send_email",
              "category" => "action",
              "label" => "Send Email Action",
              "position_x" => 100.0,
              "position_y" => 20.0
            }
          ]
        }
      }

      conn_res = post(admin_conn, ~p"/api/admin/plugins/flows", flow_params)
      assert %{"flow" => created_flow} = json_response(conn_res, 201)
      assert created_flow["name"] == "Auto Welcome Flow"
      assert created_flow["status"] == "draft"
      assert length(created_flow["nodes"]) == 2
      flow_id = created_flow["id"]

      # 3. show flow
      conn_res = get(admin_conn, ~p"/api/admin/plugins/flows/#{flow_id}")
      assert %{"flow" => fetched_flow} = json_response(conn_res, 200)
      assert fetched_flow["id"] == flow_id

      # 4. update flow
      update_params = %{
        "flow" => %{
          "name" => "Updated Welcome Flow",
          "description" => "Updated description",
          "nodes" => [
            %{
              "id" => "node-1",
              "type" => "trigger/manual",
              "category" => "trigger",
              "label" => "New Trigger",
              "position_x" => 15.0,
              "position_y" => 25.0
            }
          ]
        }
      }

      conn_res = put(admin_conn, ~p"/api/admin/plugins/flows/#{flow_id}", update_params)
      assert %{"flow" => updated_flow} = json_response(conn_res, 200)
      assert updated_flow["name"] == "Updated Welcome Flow"

      # 5. activate flow
      conn_res = put(admin_conn, ~p"/api/admin/plugins/flows/#{flow_id}/activate")
      assert %{"flow" => activated_flow} = json_response(conn_res, 200)
      assert activated_flow["status"] == "active"

      # 6. deactivate flow
      conn_res = put(admin_conn, ~p"/api/admin/plugins/flows/#{flow_id}/deactivate")
      assert %{"flow" => deactivated_flow} = json_response(conn_res, 200)
      assert deactivated_flow["status"] == "disabled"

      # 7. execute flow
      conn_res =
        post(admin_conn, ~p"/api/admin/plugins/flows/#{flow_id}/execute", %{"params" => %{}})

      assert conn_res.status == 200

      # 8. list executions and show execution
      conn_res = get(admin_conn, ~p"/api/admin/plugins/executions?flow_id=#{flow_id}")
      assert %{"executions" => executions} = json_response(conn_res, 200)
      assert length(executions) >= 1

      first_exec = hd(executions)
      exec_id = first_exec["id"]
      conn_res = get(admin_conn, ~p"/api/admin/plugins/executions/#{exec_id}")
      assert %{"execution" => single_exec} = json_response(conn_res, 200)
      assert single_exec["id"] == exec_id

      # 9. delete flow
      conn_res = delete(admin_conn, ~p"/api/admin/plugins/flows/#{flow_id}")
      assert %{"ok" => true} = json_response(conn_res, 200)
    end

    test "flow execution error and validation handling", %{conn: conn} do
      admin = create_admin_user()
      admin_conn = auth_conn(conn, admin)

      # Invalid flow creation
      conn_res = post(admin_conn, ~p"/api/admin/plugins/flows", %{"flow" => %{"name" => ""}})
      assert json_response(conn_res, 422)["error"]

      # Execute non-existent flow uuid
      random_uuid = Ecto.UUID.generate()
      conn_res = post(admin_conn, ~p"/api/admin/plugins/flows/#{random_uuid}/execute", %{})
      assert json_response(conn_res, 404)["error"] == "Flow not found"

      # Execute invalid non-uuid
      conn_res = post(admin_conn, ~p"/api/admin/plugins/flows/invalid-uuid/execute", %{})
      assert json_response(conn_res, 404)["error"] == "Flow not found"

      # Node types
      conn_res = get(admin_conn, ~p"/api/admin/plugins/node-types")
      assert %{"node_types" => node_types} = json_response(conn_res, 200)
      assert is_list(node_types)

      # Generate flow: missing description
      conn_res = post(admin_conn, ~p"/api/admin/plugins/flows/generate", %{})
      assert json_response(conn_res, 400)["error"] == "description is required"

      # Generate flow: empty description
      conn_res = post(admin_conn, ~p"/api/admin/plugins/flows/generate", %{"description" => ""})
      assert json_response(conn_res, 400)["error"] == "Description is required"

      # Generate flow: disabled
      conn_res =
        post(admin_conn, ~p"/api/admin/plugins/flows/generate", %{"description" => "Test flow"})

      assert json_response(conn_res, 503)["error"]
    end
  end

  describe "JsPluginController (JavaScript Plugins)" do
    test "js plugins lifecycle: list, create, show, update, activate, deactivate, execute, list_executions, delete",
         %{
           conn: conn
         } do
      admin = create_admin_user()
      admin_conn = auth_conn(conn, admin)

      # 1. list plugins
      conn_res = get(admin_conn, ~p"/api/admin/plugins/js")
      assert %{"plugins" => plugins} = json_response(conn_res, 200)
      assert is_list(plugins)

      # 2. create js plugin
      unique = System.unique_integer([:positive])

      plugin_params = %{
        "plugin" => %{
          "name" => "Custom JS Plugin #{unique}",
          "description" => "Test JS plugin",
          "version" => "1.0.0",
          "code" => "console.log('hello from plugin');",
          "manifest" => %{
            "hooks" => ["on_post_created"]
          },
          "settings" => %{"debug" => true}
        }
      }

      conn_res = post(admin_conn, ~p"/api/admin/plugins/js", plugin_params)
      assert %{"plugin" => plugin} = json_response(conn_res, 201)
      assert plugin["name"] == "Custom JS Plugin #{unique}"
      assert plugin["status"] == "draft"
      plugin_id = plugin["id"]

      # 3. show plugin
      conn_res = get(admin_conn, ~p"/api/admin/plugins/js/#{plugin_id}")
      assert %{"plugin" => fetched_plugin} = json_response(conn_res, 200)
      assert fetched_plugin["id"] == plugin_id
      assert fetched_plugin["code"] == "console.log('hello from plugin');"

      # 4. update plugin
      update_params = %{
        "plugin" => %{
          "name" => "Updated JS Plugin #{unique}",
          "description" => "Updated description",
          "version" => "1.0.1"
        }
      }

      conn_res = put(admin_conn, ~p"/api/admin/plugins/js/#{plugin_id}", update_params)
      assert %{"plugin" => updated_plugin} = json_response(conn_res, 200)
      assert updated_plugin["name"] == "Updated JS Plugin #{unique}"
      assert updated_plugin["version"] == "1.0.1"

      # 5. activate plugin
      conn_res = put(admin_conn, ~p"/api/admin/plugins/js/#{plugin_id}/activate")
      assert %{"plugin" => activated_plugin} = json_response(conn_res, 200)
      assert activated_plugin["status"] == "active"

      # 6. deactivate plugin
      conn_res = put(admin_conn, ~p"/api/admin/plugins/js/#{plugin_id}/deactivate")
      assert %{"plugin" => deactivated_plugin} = json_response(conn_res, 200)
      assert deactivated_plugin["status"] == "disabled"

      # 7. execute plugin (fails gracefully if deno is absent or succeeds if present)
      conn_res = post(admin_conn, ~p"/api/admin/plugins/js/#{plugin_id}/execute")
      assert conn_res.status in [200, 422]

      # 8. list executions
      conn_res = get(admin_conn, ~p"/api/admin/plugins/js/#{plugin_id}/executions")
      assert %{"executions" => executions} = json_response(conn_res, 200)
      assert is_list(executions)

      # 9. delete plugin
      conn_res = delete(admin_conn, ~p"/api/admin/plugins/js/#{plugin_id}")
      assert %{"ok" => true} = json_response(conn_res, 200)
    end

    test "js plugin validation error handling", %{conn: conn} do
      admin = create_admin_user()
      admin_conn = auth_conn(conn, admin)

      # Empty name
      conn_res = post(admin_conn, ~p"/api/admin/plugins/js", %{"plugin" => %{"name" => ""}})
      assert json_response(conn_res, 422)["error"]

      # Invalid manifest (hooks must be a list)
      conn_res =
        post(admin_conn, ~p"/api/admin/plugins/js", %{
          "plugin" => %{"name" => "Invalid Hooks", "manifest" => %{"hooks" => "not_a_list"}}
        })

      assert json_response(conn_res, 422)["error"]
    end
  end

  describe "PluginPageController" do
    test "shows published page and returns 404 for unpublished page", %{conn: conn} do
      admin = create_admin_user()
      unique = System.unique_integer([:positive])

      {:ok, flow} =
        Plugins.create_flow(%{
          name: "Flow For Page #{unique}",
          slug: "flow-for-page-#{unique}",
          trigger_type: "manual",
          created_by_id: admin.id
        })

      pub_slug = "test-pub-page-#{unique}"
      unpub_slug = "test-unpub-page-#{unique}"

      {:ok, _pub_page} =
        Plugins.upsert_page(flow.id, pub_slug, %{
          title: "Public Page",
          description: "A published page",
          is_published: true,
          template: %{"theme" => "dark"}
        })

      {:ok, _unpub_page} =
        Plugins.upsert_page(flow.id, unpub_slug, %{
          title: "Draft Page",
          is_published: false
        })

      # Public fetch published page
      conn_res = get(fresh_conn(conn), ~p"/api/pages/#{pub_slug}")
      assert %{"page" => page} = json_response(conn_res, 200)
      assert page["slug"] == pub_slug
      assert page["title"] == "Public Page"

      # Public fetch unpublished page
      conn_res = get(fresh_conn(conn), ~p"/api/pages/#{unpub_slug}")
      assert json_response(conn_res, 404)["error"] == "Page not found"
    end

    test "returns widgets for placement", %{conn: conn} do
      admin = create_admin_user()
      unique = System.unique_integer([:positive])

      {:ok, flow} =
        Plugins.create_flow(%{
          name: "Flow For Widget #{unique}",
          slug: "flow-for-widget-#{unique}",
          trigger_type: "manual",
          created_by_id: admin.id
        })

      placement = "thread_sidebar"

      {:ok, _widget} =
        Plugins.upsert_widget(flow.id, placement, %{
          template: %{"content" => "Sidebar Ads"},
          priority: 5,
          conditions: %{"role" => "all"}
        })

      conn_res = get(fresh_conn(conn), ~p"/api/widgets/#{placement}")
      assert %{"widgets" => widgets} = json_response(conn_res, 200)
      assert Enum.any?(widgets, &(&1["placement"] == placement))
    end
  end

  describe "DataTableController" do
    test "tables, columns, and rows lifecycle", %{conn: conn} do
      admin = create_admin_user()
      authed_conn = auth_conn(conn, admin)

      # 1. list tables
      res = DataTableController.list_tables(authed_conn, %{})
      assert %{"tables" => tables} = json_response(res, 200)
      assert is_list(tables)

      # 2. create table with initial columns
      unique = System.unique_integer([:positive])

      table_params = %{
        "table" => %{
          "name" => "Product Catalog #{unique}",
          "description" => "Holds product data",
          "columns" => [
            %{"name" => "Product Name", "data_type" => "string", "is_required" => true}
          ]
        }
      }

      res = DataTableController.create_table(authed_conn, table_params)
      assert %{"table" => table} = json_response(res, 201)
      assert table["name"] == "Product Catalog #{unique}"
      table_id = table["id"]
      assert length(table["columns"]) == 1

      # 3. show table
      res = DataTableController.show_table(authed_conn, %{"id" => table_id})
      assert %{"table" => fetched_table} = json_response(res, 200)
      assert fetched_table["id"] == table_id

      # 4. update table
      res =
        DataTableController.update_table(authed_conn, %{
          "id" => table_id,
          "table" => %{"description" => "Updated catalog description"}
        })

      assert %{"table" => updated_table} = json_response(res, 200)
      assert updated_table["description"] == "Updated catalog description"

      # 5. add column
      col_params = %{
        "table_id" => table_id,
        "column" => %{"name" => "Stock Count", "data_type" => "integer", "is_required" => false}
      }

      res = DataTableController.add_column(authed_conn, col_params)
      assert %{"column" => col} = json_response(res, 201)
      assert col["name"] == "Stock Count"
      col_id = col["id"]

      # 6. update column
      res =
        DataTableController.update_column(authed_conn, %{
          "id" => col_id,
          "column" => %{"name" => "Inventory Quantity"}
        })

      assert %{"column" => updated_col} = json_response(res, 200)
      assert updated_col["name"] == "Inventory Quantity"

      # 7. create row
      row_params = %{
        "table_id" => table_id,
        "row" => %{
          "data" => %{"product-name" => "Mechanical Keyboard", "stock-count" => 42}
        }
      }

      res = DataTableController.create_row(authed_conn, row_params)
      assert %{"row" => row} = json_response(res, 201)
      assert row["data"]["product-name"] == "Mechanical Keyboard"
      row_id = row["id"]

      # 8. list rows
      res = DataTableController.list_rows(authed_conn, %{"table_id" => table_id})
      assert %{"rows" => rows, "count" => count} = json_response(res, 200)
      assert count >= 1
      assert length(rows) >= 1

      # 9. show row
      res = DataTableController.show_row(authed_conn, %{"id" => row_id})
      assert %{"row" => fetched_row} = json_response(res, 200)
      assert fetched_row["id"] == row_id

      # 10. update row
      res =
        DataTableController.update_row(authed_conn, %{
          "id" => row_id,
          "row" => %{"data" => %{"product-name" => "Ergonomic Keyboard", "stock-count" => 50}}
        })

      assert %{"row" => updated_row} = json_response(res, 200)
      assert updated_row["data"]["product-name"] == "Ergonomic Keyboard"

      # 11. delete row
      res = DataTableController.delete_row(authed_conn, %{"id" => row_id})
      assert %{"ok" => true} = json_response(res, 200)

      # 12. delete column
      res = DataTableController.delete_column(authed_conn, %{"id" => col_id})
      assert %{"ok" => true} = json_response(res, 200)

      # 13. delete table
      res = DataTableController.delete_table(authed_conn, %{"id" => table_id})
      assert %{"ok" => true} = json_response(res, 200)
    end

    test "data table validation error paths", %{conn: conn} do
      admin = create_admin_user()
      authed_conn = auth_conn(conn, admin)

      # Create table without name
      res = DataTableController.create_table(authed_conn, %{"table" => %{"name" => ""}})
      assert json_response(res, 422)["error"]

      # Add invalid column
      random_uuid = Ecto.UUID.generate()

      res =
        DataTableController.add_column(authed_conn, %{
          "table_id" => random_uuid,
          "column" => %{"name" => ""}
        })

      assert json_response(res, 422)["error"]
    end
  end

  describe "WebhookController (Channel Webhooks)" do
    test "channel webhooks lifecycle: list, create, update, regenerate, execute, delete", %{
      conn: conn
    } do
      admin = create_admin_user()
      admin_conn = auth_conn(conn, admin)

      # Create chat channel
      unique = System.unique_integer([:positive])

      {:ok, channel} =
        Channels.create_channel(%{
          name: "webhook-channel-#{unique}",
          slug: "webhook-channel-#{unique}",
          type: "text",
          created_by_id: admin.id
        })

      # 1. list webhooks (initially empty)
      conn_res = get(admin_conn, ~p"/api/admin/webhooks?channel_id=#{channel.id}")
      assert %{"webhooks" => webhooks} = json_response(conn_res, 200)
      assert is_list(webhooks)

      # 2. create webhook
      conn_res =
        post(admin_conn, ~p"/api/admin/webhooks", %{
          "name" => "GitHub Integration",
          "channel_id" => channel.id
        })

      assert %{"webhook" => webhook} = json_response(conn_res, 201)
      assert webhook["name"] == "GitHub Integration"
      webhook_id = webhook["id"]
      token = webhook["token"]
      assert is_binary(token)

      # 3. update webhook
      conn_res =
        put(admin_conn, ~p"/api/admin/webhooks/#{webhook_id}", %{"name" => "GitLab Integration"})

      assert %{"webhook" => updated_webhook} = json_response(conn_res, 200)
      assert updated_webhook["name"] == "GitLab Integration"

      # 4. regenerate token
      conn_res = post(admin_conn, ~p"/api/admin/webhooks/#{webhook_id}/regenerate")
      assert %{"webhook" => regenerated} = json_response(conn_res, 200)
      new_token = regenerated["token"]
      assert is_binary(new_token)
      assert new_token != token

      # 5. public execute webhook with new token
      conn_res =
        post(fresh_conn(conn), ~p"/api/webhooks/#{new_token}", %{
          "content" => "New commit pushed to main!",
          "username" => "CI Bot"
        })

      assert %{"ok" => true, "message_id" => msg_id} = json_response(conn_res, 201)
      assert is_binary(msg_id)

      # 6. execute with empty content -> 422
      conn_res = post(fresh_conn(conn), ~p"/api/webhooks/#{new_token}", %{"content" => "   "})
      assert json_response(conn_res, 422)["error"] == "Body is required"

      # 7. execute with invalid token -> 404
      conn_res =
        post(fresh_conn(conn), ~p"/api/webhooks/invalid-token-12345", %{"content" => "Hello"})

      assert json_response(conn_res, 404)["error"] == "Invalid webhook token"

      # 8. delete webhook
      conn_res = delete(admin_conn, ~p"/api/admin/webhooks/#{webhook_id}")
      assert %{"ok" => true} = json_response(conn_res, 200)
    end
  end

  describe "ForumWebhookController" do
    test "forum webhooks lifecycle: index, create, update, test, event_types, deliveries, delete",
         %{conn: conn} do
      admin = create_admin_user()
      admin_conn = auth_conn(conn, admin)

      # 1. index
      conn_res = get(admin_conn, ~p"/api/admin/forum-webhooks")
      assert %{"webhooks" => webhooks} = json_response(conn_res, 200)
      assert is_list(webhooks)

      # 2. event types
      conn_res = get(admin_conn, ~p"/api/admin/forum-webhooks/event-types")
      assert %{"events" => events} = json_response(conn_res, 200)
      assert "forum.thread.created" in events

      # 3. create forum webhook
      unique = System.unique_integer([:positive])

      conn_res =
        post(admin_conn, ~p"/api/admin/forum-webhooks", %{
          "name" => "Discord Outbound #{unique}",
          "url" => "https://discord.com/api/webhooks/123/xyz",
          "events" => ["forum.thread.created", "forum.post.created"]
        })

      assert %{"webhook" => webhook} = json_response(conn_res, 201)
      assert webhook["name"] == "Discord Outbound #{unique}"
      webhook_id = webhook["id"]

      # 4. update forum webhook
      conn_res =
        put(admin_conn, ~p"/api/admin/forum-webhooks/#{webhook_id}", %{
          "name" => "Discord Outbound Updated #{unique}"
        })

      assert %{"webhook" => updated} = json_response(conn_res, 200)
      assert updated["name"] == "Discord Outbound Updated #{unique}"

      # 5. test forum webhook (enqueues Oban worker)
      conn_res = post(admin_conn, ~p"/api/admin/forum-webhooks/#{webhook_id}/test")
      assert %{"ok" => true, "message" => "Test webhook enqueued"} = json_response(conn_res, 200)

      # 6. deliveries list
      conn_res = get(admin_conn, ~p"/api/admin/forum-webhooks/#{webhook_id}/deliveries")
      assert %{"deliveries" => deliveries} = json_response(conn_res, 200)
      assert is_list(deliveries)

      # 7. delete forum webhook
      conn_res = delete(admin_conn, ~p"/api/admin/forum-webhooks/#{webhook_id}")
      assert %{"ok" => true} = json_response(conn_res, 200)
    end

    test "forum webhook validation error on invalid attributes", %{conn: conn} do
      admin = create_admin_user()
      admin_conn = auth_conn(conn, admin)

      # Missing url and events
      conn_res = post(admin_conn, ~p"/api/admin/forum-webhooks", %{"name" => "Bad Webhook"})
      assert json_response(conn_res, 422)["error"]
    end
  end

  describe "ForumPermissionController" do
    test "index and update forum permissions", %{conn: conn} do
      admin = create_admin_user()
      authed_conn = auth_conn(conn, admin)

      unique = System.unique_integer([:positive])

      {:ok, cat} =
        Forums.create_category(%{
          name: "Perm Category #{unique}",
          position: 1
        })

      {:ok, forum} =
        Forums.create_forum(%{
          name: "Perm Forum #{unique}",
          slug: "perm-forum-#{unique}",
          category_id: cat.id,
          position: 1
        })

      {:ok, group} =
        Accounts.create_group(%{
          name: "Perm Group #{unique}",
          slug: "perm-group-#{unique}",
          color: "#00FF00"
        })

      # 1. index forum permissions
      res = ForumPermissionController.index(authed_conn, %{"id" => forum.id})
      assert %{"permissions" => permissions} = json_response(res, 200)
      assert is_list(permissions)

      # 2. update forum permissions
      perm_update = %{
        "id" => forum.id,
        "permissions" => [
          %{
            "group_id" => group.id,
            "can_view" => true,
            "can_post" => true,
            "can_create_threads" => false
          }
        ]
      }

      res = ForumPermissionController.update(authed_conn, perm_update)
      assert %{"ok" => true, "permissions" => updated_perms} = json_response(res, 200)
      assert is_list(updated_perms)
    end
  end

  describe "CommunityController" do
    test "community management: index, create, show, update, delete", %{conn: conn} do
      admin = create_admin_user()
      admin_conn = auth_conn(conn, admin)

      # 1. index communities
      conn_res = get(admin_conn, ~p"/api/admin/communities")
      assert %{"communities" => communities} = json_response(conn_res, 200)
      assert is_list(communities)

      # 2. create community
      unique = System.unique_integer([:positive])
      slug = "comm-#{unique}"

      comm_params = %{
        "name" => "Gaming Guild #{unique}",
        "slug" => slug,
        "subdomain" => slug,
        "description" => "Guild description"
      }

      conn_res = post(admin_conn, ~p"/api/admin/communities", comm_params)
      assert %{"community" => community} = json_response(conn_res, 201)
      assert community["name"] == "Gaming Guild #{unique}"
      assert community["slug"] == slug
      comm_id = community["id"]

      # 3. show community
      conn_res = get(admin_conn, ~p"/api/admin/communities/#{comm_id}")
      assert %{"community" => fetched_community} = json_response(conn_res, 200)
      assert fetched_community["id"] == comm_id

      # 4. update community
      conn_res =
        put(admin_conn, ~p"/api/admin/communities/#{comm_id}", %{
          "description" => "Updated guild description"
        })

      assert %{"community" => updated} = json_response(conn_res, 200)
      assert updated["description"] == "Updated guild description"

      # 5. delete community
      conn_res = delete(admin_conn, ~p"/api/admin/communities/#{comm_id}")
      assert %{"ok" => true} = json_response(conn_res, 200)
    end

    test "community validation error on invalid attributes", %{conn: conn} do
      admin = create_admin_user()
      admin_conn = auth_conn(conn, admin)

      # Invalid slug format
      conn_res =
        post(admin_conn, ~p"/api/admin/communities", %{
          "name" => "Invalid Community",
          "slug" => "INVALID SLUG WITH SPACES"
        })

      assert json_response(conn_res, 422)["error"]
    end
  end

  describe "CommunitySignupController" do
    test "show_public for active community and 404 for missing or inactive", %{conn: conn} do
      admin = create_admin_user()
      unique = System.unique_integer([:positive])
      active_slug = "active-comm-#{unique}"
      inactive_slug = "inactive-comm-#{unique}"

      {:ok, _active_comm} =
        Communities.create_community(%{
          name: "Active Community #{unique}",
          slug: active_slug,
          subdomain: active_slug,
          is_active: true,
          owner_id: admin.id
        })

      {:ok, _inactive_comm} =
        Communities.create_community(%{
          name: "Inactive Community #{unique}",
          slug: inactive_slug,
          subdomain: inactive_slug,
          is_active: false,
          owner_id: admin.id
        })

      # Active community lookup
      conn_res = get(fresh_conn(conn), ~p"/api/communities/#{active_slug}")
      assert %{"community" => comm} = json_response(conn_res, 200)
      assert comm["slug"] == active_slug
      assert comm["name"] == "Active Community #{unique}"

      # Inactive community lookup -> 404
      conn_res = get(fresh_conn(conn), ~p"/api/communities/#{inactive_slug}")
      assert json_response(conn_res, 404)["error"] == "Community not active"

      # Non-existent community -> 404
      conn_res = get(fresh_conn(conn), ~p"/api/communities/non-existent-community-xyz")
      assert json_response(conn_res, 404)["error"] == "Community not found"
    end

    test "member signup: successful member registration and validation errors", %{conn: conn} do
      admin = create_admin_user()
      unique = System.unique_integer([:positive])
      slug = "signup-comm-#{unique}"

      {:ok, _comm} =
        Communities.create_community(%{
          name: "Signup Community #{unique}",
          slug: slug,
          subdomain: slug,
          is_active: true,
          owner_id: admin.id
        })

      # 1. Missing fields -> 400
      conn_res =
        post(fresh_conn(conn), ~p"/api/communities/#{slug}/members/signup", %{
          "email" => "user@example.com"
        })

      assert json_response(conn_res, 400)["error"] == "Missing fields"

      # 2. Signup to non-existent community -> 404
      conn_res =
        post(fresh_conn(conn), ~p"/api/communities/non-existent-comm/members/signup", %{
          "email" => "test@example.com",
          "password" => "ValidPassword123!@#",
          "display_name" => "Member Test"
        })

      assert json_response(conn_res, 404)["error"] == "Community not found"

      # 3. Successful member signup
      member_email = "member_#{unique}@example.com"

      conn_res =
        post(fresh_conn(conn), ~p"/api/communities/#{slug}/members/signup", %{
          "email" => member_email,
          "password" => "ValidPassword123!@#",
          "display_name" => "Awesome Member #{unique}"
        })

      assert %{
               "community_slug" => ^slug,
               "role" => "member",
               "token" => token,
               "user_id" => user_id
             } = json_response(conn_res, 200)

      assert is_binary(token)
      assert is_binary(user_id)
    end
  end

  describe "BillingController" do
    test "plans lists billing catalog including houses entry", %{conn: conn} do
      conn_res = get(fresh_conn(conn), ~p"/api/billing/plans")
      assert %{"plans" => plans} = json_response(conn_res, 200)
      assert is_list(plans)
      assert Enum.any?(plans, &(&1["plan"] == "houses"))
    end

    test "create_checkout and show subscription permissions and validations", %{conn: conn} do
      owner = create_user()
      other_user = create_user()
      unique = System.unique_integer([:positive])
      slug = "billing-comm-#{unique}"

      {:ok, community} =
        Communities.create_community(%{
          name: "Billing Community #{unique}",
          slug: slug,
          subdomain: slug,
          owner_id: owner.id
        })

      owner_conn = auth_conn(conn, owner)
      other_conn = auth_conn(conn, other_user)

      # 1. Non-owner cannot create checkout -> 403
      conn_res =
        post(other_conn, ~p"/api/billing/communities/#{community.id}/checkout", %{
          "plan" => "forum"
        })

      assert json_response(conn_res, 403)["error"] ==
               "Only the community owner can manage billing"

      # 2. Non-existent community -> 404
      random_uuid = Ecto.UUID.generate()

      conn_res =
        post(owner_conn, ~p"/api/billing/communities/#{random_uuid}/checkout", %{
          "plan" => "forum"
        })

      assert json_response(conn_res, 404)["error"] == "Community not found"

      # 3. Invalid plan -> 422
      conn_res =
        post(owner_conn, ~p"/api/billing/communities/#{community.id}/checkout", %{
          "plan" => "invalid_plan_tier"
        })

      assert json_response(conn_res, 422)["error"] == "Invalid plan"

      # 4. Valid plan with unconfigured pricing -> 503
      conn_res =
        post(owner_conn, ~p"/api/billing/communities/#{community.id}/checkout", %{
          "plan" => "forum"
        })

      assert json_response(conn_res, 503)["error"] =~ "not configured yet"

      # 5. Show subscription: owner gets 200
      conn_res = get(owner_conn, ~p"/api/billing/communities/#{community.id}/subscription")
      assert %{"plan" => "free"} = json_response(conn_res, 200)

      # 6. Show subscription: non-owner gets 403
      conn_res = get(other_conn, ~p"/api/billing/communities/#{community.id}/subscription")
      assert json_response(conn_res, 403)["error"] == "Owner only"

      # 7. Show subscription: non-existent gets 404
      conn_res = get(owner_conn, ~p"/api/billing/communities/#{random_uuid}/subscription")
      assert json_response(conn_res, 404)["error"] == "Not found"
    end
  end

  describe "SubscriptionController" do
    test "tiers lists public tiers", %{conn: conn} do
      unique = System.unique_integer([:positive])

      {:ok, _tier} =
        Subscriptions.create_tier(%{
          name: "Gold Member #{unique}",
          slug: "gold-member-#{unique}",
          tier_level: 2,
          price_monthly: Decimal.new("9.99"),
          price_yearly: Decimal.new("99.99"),
          is_active: true
        })

      conn_res = get(fresh_conn(conn), ~p"/api/subscriptions/tiers")
      assert %{"tiers" => tiers} = json_response(conn_res, 200)
      assert is_list(tiers)
      assert Enum.any?(tiers, &(&1["slug"] == "gold-member-#{unique}"))
    end

    test "my_subscription, create and cancel user subscription", %{conn: conn} do
      user = create_user()
      authed_conn = auth_conn(conn, user)
      unique = System.unique_integer([:positive])

      {:ok, tier} =
        Subscriptions.create_tier(%{
          name: "Diamond Tier #{unique}",
          slug: "diamond-tier-#{unique}",
          tier_level: 3,
          price_monthly: Decimal.new("24.99"),
          price_yearly: Decimal.new("249.99"),
          is_active: true
        })

      # 1. No active subscription initially
      res = SubscriptionController.my_subscription(authed_conn, %{})
      assert %{"subscription" => nil} = json_response(res, 200)

      # 2. Subscribe to non-existent tier -> 404
      random_uuid = Ecto.UUID.generate()
      res = SubscriptionController.create(authed_conn, %{"tier_id" => random_uuid})
      assert json_response(res, 404)["error"] == "Tier not found"

      # 3. Cancel with no active subscription -> 404
      res = SubscriptionController.cancel(authed_conn, %{})
      assert json_response(res, 404)["error"] == "No active subscription"

      # 4. Subscribe to tier -> 201
      res = SubscriptionController.create(authed_conn, %{"tier_id" => tier.id})
      assert %{"subscription" => sub} = json_response(res, 201)
      assert sub["status"] == "active"
      assert sub["tier"]["id"] == tier.id

      # 5. Check my_subscription returns active subscription
      res = SubscriptionController.my_subscription(authed_conn, %{})
      assert %{"subscription" => active_sub} = json_response(res, 200)
      assert active_sub["id"] == sub["id"]

      # 6. Cancel subscription
      res = SubscriptionController.cancel(authed_conn, %{})
      assert %{"subscription" => cancelled_sub} = json_response(res, 200)
      assert cancelled_sub["status"] == "cancelled"
    end
  end

  describe "ApplicationController" do
    test "open_forms, show_form, and admin forms management", %{conn: conn} do
      admin = create_admin_user()
      admin_conn = auth_conn(conn, admin)
      unique = System.unique_integer([:positive])

      # 1. Admin creates form
      form_attrs = %{
        "title" => "Community Mod Form #{unique}",
        "description" => "Apply to become a community moderator",
        "fields" => [%{"label" => "Discord Handle", "type" => "text"}],
        "is_open" => true,
        "min_posts" => 0,
        "min_days_member" => 0
      }

      res = ApplicationController.create_form(admin_conn, form_attrs)
      assert %{"form" => form} = json_response(res, 201)
      assert form["title"] == "Community Mod Form #{unique}"
      form_id = form["id"]

      # 2. Public list open forms
      conn_res = get(fresh_conn(conn), ~p"/api/applications/forms")
      assert %{"forms" => open_forms} = json_response(conn_res, 200)
      assert Enum.any?(open_forms, &(&1["id"] == form_id))

      # 3. Public show form
      conn_res = get(fresh_conn(conn), ~p"/api/applications/forms/#{form_id}")
      assert %{"form" => fetched_form} = json_response(conn_res, 200)
      assert fetched_form["id"] == form_id

      # 4. Admin list all forms
      res = ApplicationController.admin_list_forms(admin_conn, %{})
      assert %{"forms" => all_forms} = json_response(res, 200)
      assert Enum.any?(all_forms, &(&1["id"] == form_id))

      # 5. Admin update form
      res =
        ApplicationController.update_form(admin_conn, %{
          "id" => form_id,
          "description" => "Updated mod application requirements"
        })

      assert %{"form" => updated_form} = json_response(res, 200)
      assert updated_form["description"] == "Updated mod application requirements"

      # 6. Admin delete form
      res = ApplicationController.delete_form(admin_conn, %{"id" => form_id})
      assert %{"ok" => true} = json_response(res, 200)
    end

    test "applications workflow: submit, my_applications, list_applications, review", %{
      conn: conn
    } do
      admin = create_admin_user()
      applicant = create_user()
      admin_conn = auth_conn(conn, admin)
      applicant_conn = auth_conn(conn, applicant)
      unique = System.unique_integer([:positive])

      # Create an open form
      {:ok, form} =
        Applications.create_form(%{
          "title" => "Helper Application #{unique}",
          "description" => "Help new members",
          "fields" => [%{"label" => "Experience", "type" => "text"}],
          "is_open" => true,
          "min_posts" => 0,
          "min_days_member" => 0
        })

      # 1. Applicant submits application
      submit_params = %{
        "form_id" => form.id,
        "answers" => [%{"question" => "Experience", "answer" => "3 years forum modding"}]
      }

      res = ApplicationController.submit(applicant_conn, submit_params)
      assert %{"application" => app} = json_response(res, 201)
      assert app["status"] == "pending"
      app_id = app["id"]

      # 2. Duplicate submission blocked
      res = ApplicationController.submit(applicant_conn, submit_params)
      assert json_response(res, 403)["error"] == "already_applied"

      # 3. Applicant checks my_applications
      res = ApplicationController.my_applications(applicant_conn, %{})
      assert %{"applications" => my_apps} = json_response(res, 200)
      assert Enum.any?(my_apps, &(&1["id"] == app_id))

      # 4. Admin lists applications
      res = ApplicationController.list_applications(admin_conn, %{"status" => "pending"})
      assert %{"applications" => apps} = json_response(res, 200)
      assert Enum.any?(apps, &(&1["id"] == app_id))

      # 5. Admin reviews application
      review_params = %{
        "id" => app_id,
        "status" => "accepted",
        "note" => "Great experience, approved!"
      }

      res = ApplicationController.review(admin_conn, review_params)
      assert %{"application" => reviewed_app} = json_response(res, 200)
      assert reviewed_app["status"] == "accepted"
      assert reviewed_app["review_note"] == "Great experience, approved!"
    end
  end
end
