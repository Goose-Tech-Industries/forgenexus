defmodule ForgeNexusWeb.PluginController do
  use ForgeNexusWeb, :controller

  alias ForgeNexus.Plugins
  alias ForgeNexus.Plugins.Nodes.Registry
  alias ForgeNexus.Plugins.Engine.Executor

  def list_flows(conn, params) do
    opts = [
      status: Map.get(params, "status"),
      trigger_type: Map.get(params, "trigger_type"),
      limit: parse_int(params, "limit", 25),
      offset: parse_int(params, "offset", 0)
    ]
    flows = Plugins.list_flows(opts)
    conn |> json(%{flows: Enum.map(flows, &flow_json/1)})
  end

  def show_flow(conn, %{"id" => id}) do
    flow = Plugins.get_flow!(id)
    conn |> json(%{flow: flow_detail_json(flow)})
  end

  def create_flow(conn, %{"flow" => flow_params}) do
    user = Guardian.Plug.current_resource(conn)
    slug = (Map.get(flow_params, "name") || "") |> String.downcase() |> String.replace(~r/[^a-z0-9\s-]/, "") |> String.replace(~r/\s+/, "-") |> String.trim("-")
    attrs = %{
      name: Map.get(flow_params, "name"), description: Map.get(flow_params, "description"),
      slug: slug, trigger_type: Map.get(flow_params, "trigger_type"),
      trigger_config: Map.get(flow_params, "trigger_config", %{}),
      settings: Map.get(flow_params, "settings", %{}), created_by_id: user.id
    }
    case Plugins.create_flow(attrs) do
      {:ok, flow} ->
        nodes_attrs = Map.get(flow_params, "nodes", [])
        edges_attrs = Map.get(flow_params, "edges", [])
        if nodes_attrs != [] do
          Plugins.bulk_create_nodes(flow.id, Enum.map(nodes_attrs, fn n ->
            %{type: Map.get(n, "type"), category: Map.get(n, "category"), label: Map.get(n, "label"),
              config: Map.get(n, "config", %{}), position_x: Map.get(n, "position_x", 0.0),
              position_y: Map.get(n, "position_y", 0.0), position: Map.get(n, "position", 0)}
          end))
        end
        if edges_attrs != [] do
          Plugins.bulk_create_edges(flow.id, Enum.map(edges_attrs, fn e ->
            %{source_node_id: Map.get(e, "source_node_id"), target_node_id: Map.get(e, "target_node_id"),
              source_port: Map.get(e, "source_port", "output"), target_port: Map.get(e, "target_port", "input"),
              condition: Map.get(e, "condition"), position: Map.get(e, "position", 0)}
          end))
        end
        flow = Plugins.get_flow!(flow.id)
        conn |> put_status(:created) |> json(%{flow: flow_detail_json(flow)})
      {:error, changeset} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: changeset_errors(changeset)})
    end
  end

  def update_flow(conn, %{"id" => id, "flow" => flow_params}) do
    attrs = flow_params |> Map.take(["name", "description", "trigger_type", "trigger_config", "settings"])
      |> Enum.map(fn {k, v} -> {String.to_existing_atom(k), v} end) |> Map.new()
    attrs = if Map.has_key?(attrs, :name) do
      slug = attrs[:name] |> String.downcase() |> String.replace(~r/[^a-z0-9\s-]/, "") |> String.replace(~r/\s+/, "-") |> String.trim("-")
      Map.put(attrs, :slug, slug)
    else
      attrs
    end
    case Plugins.update_flow(id, attrs) do
      {:ok, flow} ->
        nodes_attrs = Map.get(flow_params, "nodes")
        edges_attrs = Map.get(flow_params, "edges")

        # Rebuild graph atomically: always delete edges first (they reference nodes),
        # then delete/recreate nodes, then recreate edges with new node IDs.
        if nodes_attrs || edges_attrs do
          flow_loaded = Plugins.get_flow!(id)

          # Always clear edges first when rebuilding any part of the graph
          for edge <- flow_loaded.edges, do: Plugins.delete_edge(edge.id)

          # Rebuild nodes if provided, building an old_id -> new_id mapping
          node_id_map =
            if nodes_attrs do
              for node <- flow_loaded.nodes, do: Plugins.delete_node(node.id)
              new_nodes = Plugins.bulk_create_nodes(flow.id, Enum.map(nodes_attrs, fn n ->
                %{type: Map.get(n, "type"), category: Map.get(n, "category"), label: Map.get(n, "label"),
                  config: Map.get(n, "config", %{}), position_x: Map.get(n, "position_x", 0.0),
                  position_y: Map.get(n, "position_y", 0.0), position: Map.get(n, "position", 0)}
              end))
              # Map client-provided IDs to newly created IDs by position order
              nodes_attrs
              |> Enum.with_index()
              |> Enum.reduce(%{}, fn {n, idx}, acc ->
                client_id = Map.get(n, "id")
                new_node = Enum.at(List.wrap(new_nodes), idx)
                if client_id && new_node, do: Map.put(acc, client_id, new_node.id), else: acc
              end)
            else
              %{}
            end

          # Recreate edges, remapping node IDs if nodes were also rebuilt
          if edges_attrs do
            Plugins.bulk_create_edges(flow.id, Enum.map(edges_attrs, fn e ->
              source_id = Map.get(e, "source_node_id")
              target_id = Map.get(e, "target_node_id")
              %{
                source_node_id: Map.get(node_id_map, source_id, source_id),
                target_node_id: Map.get(node_id_map, target_id, target_id),
                source_port: Map.get(e, "source_port", "output"),
                target_port: Map.get(e, "target_port", "input"),
                condition: Map.get(e, "condition"),
                position: Map.get(e, "position", 0)
              }
            end))
          end
        end

        flow = Plugins.get_flow!(id)
        conn |> json(%{flow: flow_detail_json(flow)})
      {:error, changeset} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: changeset_errors(changeset)})
    end
  end

  def delete_flow(conn, %{"id" => id}) do
    case Plugins.delete_flow(id) do
      {:ok, _} -> conn |> json(%{ok: true})
      {:error, _} -> conn |> put_status(:unprocessable_entity) |> json(%{error: "Failed to delete flow"})
    end
  end

  def activate_flow(conn, %{"id" => id}) do
    case Plugins.activate_flow(id) do
      {:ok, flow} ->
        flow = ForgeNexus.Repo.preload(flow, [:created_by, :nodes, :edges])
        conn |> json(%{flow: flow_json(flow)})
      {:error, errors} when is_list(errors) ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: Enum.join(errors, "; ")})
      {:error, changeset} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: changeset_errors(changeset)})
    end
  end

  def deactivate_flow(conn, %{"id" => id}) do
    case Plugins.deactivate_flow(id) do
      {:ok, flow} ->
        flow = ForgeNexus.Repo.preload(flow, [:created_by, :nodes, :edges])
        conn |> json(%{flow: flow_json(flow)})
      {:error, changeset} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: changeset_errors(changeset)})
    end
  end

  def execute_flow(conn, %{"id" => id} = params) do
    user = Guardian.Plug.current_resource(conn)
    trigger_params = Map.get(params, "params", %{})

    cond do
      not is_binary(id) or Ecto.UUID.cast(id) == :error ->
        conn |> put_status(:not_found) |> json(%{error: "Flow not found"})

      is_nil(ForgeNexus.Repo.get(ForgeNexus.Plugins.Flow, id)) ->
        conn |> put_status(:not_found) |> json(%{error: "Flow not found"})

      true ->
        case Executor.execute_flow(id, trigger_params, user.id) do
          {:ok, execution} -> conn |> json(%{execution: execution_json(execution)})
          {:error, reason} -> conn |> put_status(:unprocessable_entity) |> json(%{error: inspect(reason)})
        end
    end
  end

  def list_executions(conn, params) do
    opts = [flow_id: Map.get(params, "flow_id"), status: Map.get(params, "status"),
      limit: parse_int(params, "limit", 25), offset: parse_int(params, "offset", 0)]
    executions = Plugins.list_executions(opts)
    conn |> json(%{executions: Enum.map(executions, &execution_json/1)})
  end

  def show_execution(conn, %{"id" => id}) do
    execution = Plugins.get_execution!(id)
    conn |> json(%{execution: execution_json(execution)})
  end

  def node_types(conn, _params) do
    types = Registry.all_types()
    type_list = Enum.map(types, fn {type, schema} -> %{type: type, schema: schema} end)
    conn |> json(%{node_types: type_list})
  end

  def generate_flow(conn, %{"description" => description} = params) do
    autosave? = Map.get(params, "save", true) != false

    case ForgeNexus.Plugins.FlowGenerator.generate(description) do
      {:ok, spec} ->
        if autosave? do
          admin = Guardian.Plug.current_resource(conn)

          case Plugins.create_flow_from_spec(spec, admin && admin.id) do
            {:ok, flow} ->
              conn |> put_status(:created) |> json(%{flow: flow_json(flow), spec: spec})

            {:error, reason} ->
              conn
              |> put_status(:unprocessable_entity)
              |> json(%{error: "Generated spec rejected by persistence: #{inspect(reason)}", spec: spec})
          end
        else
          conn |> json(%{spec: spec})
        end

      {:error, :disabled} ->
        conn
        |> put_status(:service_unavailable)
        |> json(%{error: "AI flow generator is disabled in admin settings"})

      {:error, :no_api_key} ->
        conn
        |> put_status(:service_unavailable)
        |> json(%{error: "ANTHROPIC_API_KEY environment variable not set"})

      {:error, :empty_description} ->
        conn |> put_status(:bad_request) |> json(%{error: "Description is required"})

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Generation failed", reason: inspect(reason)})
    end
  end

  def generate_flow(conn, _params),
    do: conn |> put_status(:bad_request) |> json(%{error: "description is required"})

  defp flow_json(flow) do
    nodes = if Ecto.assoc_loaded?(flow.nodes), do: flow.nodes, else: []
    edges = if Ecto.assoc_loaded?(flow.edges), do: flow.edges, else: []
    %{id: flow.id, name: flow.name, description: flow.description, slug: flow.slug,
      status: flow.status, tier: flow.tier, version: flow.version,
      trigger_type: flow.trigger_type, trigger_config: flow.trigger_config,
      settings: flow.settings, error_message: flow.error_message,
      last_executed_at: flow.last_executed_at, execution_count: flow.execution_count,
      inserted_at: flow.inserted_at, updated_at: flow.updated_at,
      created_by: if(Ecto.assoc_loaded?(flow.created_by), do: user_mini_json(flow.created_by)),
      node_count: length(nodes), edge_count: length(edges)}
  end

  defp flow_detail_json(flow) do
    base = flow_json(flow)
    nodes = if Ecto.assoc_loaded?(flow.nodes), do: flow.nodes, else: []
    edges = if Ecto.assoc_loaded?(flow.edges), do: flow.edges, else: []
    Map.merge(base, %{nodes: Enum.map(nodes, &node_json/1), edges: Enum.map(edges, &edge_json/1)})
  end

  defp node_json(node) do
    %{id: node.id, flow_id: node.flow_id, type: node.type, category: node.category,
      label: node.label, config: node.config, position_x: node.position_x,
      position_y: node.position_y, position: node.position,
      inserted_at: node.inserted_at, updated_at: node.updated_at}
  end

  defp edge_json(edge) do
    %{id: edge.id, flow_id: edge.flow_id, source_node_id: edge.source_node_id,
      target_node_id: edge.target_node_id, source_port: edge.source_port,
      target_port: edge.target_port, condition: edge.condition, position: edge.position,
      inserted_at: edge.inserted_at, updated_at: edge.updated_at}
  end

  defp execution_json(exec) do
    %{id: exec.id, flow_id: exec.flow_id, status: exec.status,
      trigger_type: exec.trigger_type, trigger_data: exec.trigger_data,
      result: exec.result, node_trace: exec.node_trace,
      started_at: exec.started_at, finished_at: exec.finished_at,
      duration_ms: exec.duration_ms, nodes_executed: exec.nodes_executed,
      db_operations: exec.db_operations, http_requests: exec.http_requests,
      inserted_at: exec.inserted_at}
  end

  defp user_mini_json(nil), do: nil
  defp user_mini_json(user), do: %{id: user.id, username: user.username, slug: user.slug, avatar_url: user.avatar_url}

  defp parse_int(params, key, default) do
    case Map.get(params, key) do
      nil -> default
      val when is_binary(val) -> safe_to_integer(val, default)
      val when is_integer(val) -> val
    end
  end

  defp changeset_errors(%Ecto.Changeset{} = changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, _opts} -> msg end)
  end
  defp changeset_errors(error), do: inspect(error)

  defp safe_to_integer(val, default) when is_binary(val) do
    case Integer.parse(val) do
      {int, _} -> int
      :error -> default
    end
  end
  defp safe_to_integer(val, _default) when is_integer(val), do: val
  defp safe_to_integer(_, default), do: default

end
