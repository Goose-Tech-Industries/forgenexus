defmodule ForgeNexus.Plugins do
  @moduledoc """
  Context for the ForgeNexus plugin system.
  Manages flows, nodes, edges, and plugin configuration.
  """

  import Ecto.Query
  alias ForgeNexus.Repo
  alias ForgeNexus.Plugins.{Flow, FlowNode, FlowEdge, FlowExecution, FlowGlobalStore, PluginPage, PluginWidget}

  # =====================
  # Flows
  # =====================

  def create_flow(attrs) do
    %Flow{}
    |> Flow.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Persist a generated flow spec (see `ForgeNexus.Plugins.FlowGenerator`) as a
  real Flow + FlowNodes + FlowEdges in a single transaction.

  The spec's node `client_id`s are resolved to the inserted DB ids before
  edges are created. Returns `{:ok, flow}` (with nodes and edges preloaded)
  or `{:error, reason}`.
  """
  @canonical_trigger_types ~w(on_post_created on_thread_created on_user_joined on_user_left on_reaction_added on_chat_message scheduled manual webhook_received on_custom_event on_slash_command)

  def create_flow_from_spec(spec, created_by_id) when is_map(spec) do
    raw_trigger = Map.fetch!(spec, :trigger_type)
    {canonical_trigger, trigger_config} =
      normalize_trigger(raw_trigger, Map.get(spec, :trigger_config, %{}))

    Repo.transaction(fn ->
      flow_attrs = %{
        name: Map.fetch!(spec, :name),
        description: Map.get(spec, :description),
        slug: generate_unique_slug(Map.fetch!(spec, :name)),
        status: "draft",
        tier: "nocode",
        trigger_type: canonical_trigger,
        trigger_config: trigger_config,
        created_by_id: created_by_id
      }

      flow =
        case %Flow{} |> Flow.changeset(flow_attrs) |> Repo.insert() do
          {:ok, f} -> f
          {:error, cs} -> Repo.rollback({:flow_insert_failed, cs})
        end

      # Insert nodes, capturing the client_id → db_id mapping
      id_map =
        spec.nodes
        |> Enum.with_index()
        |> Enum.reduce(%{}, fn {node, idx}, acc ->
          category =
            case String.split(node.type, "/", parts: 2) do
              [cat, _] -> cat
              _ -> "action"
            end

          attrs = %{
            flow_id: flow.id,
            type: node.type,
            category: category,
            label: Map.get(node, :label),
            config: Map.get(node, :config, %{}),
            position_x: 100.0 + rem(idx, 4) * 220.0,
            position_y: 100.0 + div(idx, 4) * 140.0,
            position: idx
          }

          case %FlowNode{} |> FlowNode.changeset(attrs) |> Repo.insert() do
            {:ok, inserted} -> Map.put(acc, node.client_id, inserted.id)
            {:error, cs} -> Repo.rollback({:node_insert_failed, cs})
          end
        end)

      # Insert edges, resolving client ids
      spec.edges
      |> Enum.with_index()
      |> Enum.each(fn {edge, idx} ->
        source_id = Map.get(id_map, edge.source)
        target_id = Map.get(id_map, edge.target)

        if is_nil(source_id) or is_nil(target_id) do
          Repo.rollback({:edge_unresolved, edge})
        end

        attrs = %{
          flow_id: flow.id,
          source_node_id: source_id,
          target_node_id: target_id,
          source_port: Map.get(edge, :source_port, "output"),
          target_port: Map.get(edge, :target_port, "input"),
          position: idx
        }

        case %FlowEdge{} |> FlowEdge.changeset(attrs) |> Repo.insert() do
          {:ok, _} -> :ok
          {:error, cs} -> Repo.rollback({:edge_insert_failed, cs})
        end
      end)

      Repo.preload(flow, [:nodes, :edges])
    end)
  end

  # Map a free-form trigger identifier (e.g. "trigger/on_poll_voted" or
  # "on_post_created") to the canonical Flow.trigger_type. Unknown triggers
  # fall through to "on_custom_event" with the original name preserved in
  # trigger_config.event_name so the runtime can still dispatch by event.
  defp normalize_trigger(raw, trigger_config) when is_binary(raw) do
    short =
      case String.split(raw, "/", parts: 2) do
        ["trigger", rest] -> rest
        _ -> raw
      end

    cond do
      short in @canonical_trigger_types ->
        {short, trigger_config || %{}}

      true ->
        event_name = short
        enriched = Map.put(trigger_config || %{}, "event_name", event_name)
        {"on_custom_event", enriched}
    end
  end

  defp normalize_trigger(_, trigger_config), do: {"manual", trigger_config || %{}}

  defp generate_unique_slug(name) do
    base =
      name
      |> String.downcase()
      |> String.replace(~r/[^a-z0-9]+/, "-")
      |> String.trim("-")
      |> String.slice(0, 50)

    base = if base == "", do: "flow", else: base
    suffix = :crypto.strong_rand_bytes(4) |> Base.url_encode64(padding: false)
    "#{base}-#{suffix}"
  end

  def update_flow(flow_id, attrs) do
    Repo.get!(Flow, flow_id)
    |> Flow.changeset(attrs)
    |> Repo.update()
  end

  def delete_flow(flow_id) do
    Repo.get!(Flow, flow_id)
    |> Repo.delete()
  end

  def get_flow!(id) do
    Repo.get!(Flow, id) |> Repo.preload([:nodes, :edges, :created_by])
  end

  def get_flow_with_graph!(id) do
    flow = Repo.get!(Flow, id) |> Repo.preload([:nodes, :edges])
    nodes_map = Map.new(flow.nodes, &{&1.id, &1})

    edges_by_source =
      Enum.group_by(flow.edges, & &1.source_node_id)
      |> Enum.map(fn {k, v} -> {k, Enum.sort_by(v, & &1.position)} end)
      |> Map.new()

    {flow, nodes_map, edges_by_source}
  end

  def list_flows(opts \\ []) do
    status = Keyword.get(opts, :status)
    trigger_type = Keyword.get(opts, :trigger_type)
    limit = Keyword.get(opts, :limit, 25)
    offset = Keyword.get(opts, :offset, 0)

    query =
      from f in Flow,
        order_by: [desc: :updated_at],
        limit: ^limit,
        offset: ^offset,
        preload: [:created_by]

    query = if status, do: where(query, [f], f.status == ^status), else: query
    query = if trigger_type, do: where(query, [f], f.trigger_type == ^trigger_type), else: query

    Repo.all(query)
  end

  def activate_flow(flow_id) do
    flow = Repo.get!(Flow, flow_id)

    case validate_flow(flow) do
      :ok ->
        flow |> Flow.status_changeset(%{status: "active", error_message: nil}) |> Repo.update()

      {:error, errors} ->
        flow
        |> Flow.status_changeset(%{status: "error", error_message: Enum.join(errors, "; ")})
        |> Repo.update()

        {:error, errors}
    end
  end

  def deactivate_flow(flow_id) do
    Repo.get!(Flow, flow_id)
    |> Flow.status_changeset(%{status: "disabled"})
    |> Repo.update()
  end

  def validate_flow(flow) do
    flow = Repo.preload(flow, [:nodes, :edges])
    errors = []

    # Must have exactly one trigger node
    trigger_nodes = Enum.filter(flow.nodes, &(&1.category == "trigger"))

    errors =
      case length(trigger_nodes) do
        0 -> ["Flow must have at least one trigger node" | errors]
        1 -> errors
        _ -> ["Flow must have exactly one trigger node" | errors]
      end

    # Max 200 nodes
    errors =
      if length(flow.nodes) > 200 do
        ["Flow cannot have more than 200 nodes" | errors]
      else
        errors
      end

    # All edge references must be valid
    node_ids = MapSet.new(flow.nodes, & &1.id)

    invalid_edges =
      Enum.filter(flow.edges, fn e ->
        not MapSet.member?(node_ids, e.source_node_id) or
          not MapSet.member?(node_ids, e.target_node_id)
      end)

    errors =
      if invalid_edges != [] do
        ["#{length(invalid_edges)} edge(s) reference non-existent nodes" | errors]
      else
        errors
      end

    if errors == [], do: :ok, else: {:error, Enum.reverse(errors)}
  end

  def record_execution(flow_id) do
    from(f in Flow, where: f.id == ^flow_id)
    |> Repo.update_all(
      inc: [execution_count: 1],
      set: [last_executed_at: DateTime.utc_now() |> DateTime.truncate(:second)]
    )
  end

  # =====================
  # Flow Nodes
  # =====================

  def create_node(attrs) do
    %FlowNode{}
    |> FlowNode.changeset(attrs)
    |> Repo.insert()
  end

  def update_node(node_id, attrs) do
    Repo.get!(FlowNode, node_id)
    |> FlowNode.changeset(attrs)
    |> Repo.update()
  end

  def delete_node(node_id) do
    node = Repo.get!(FlowNode, node_id)
    # Cascade will handle edges
    Repo.delete(node)
  end

  def bulk_create_nodes(flow_id, nodes_attrs) do
    Repo.transaction(fn ->
      Enum.map(nodes_attrs, fn attrs ->
        {:ok, node} = create_node(Map.put(attrs, :flow_id, flow_id))
        node
      end)
    end)
  end

  # =====================
  # Flow Edges
  # =====================

  def create_edge(attrs) do
    %FlowEdge{}
    |> FlowEdge.changeset(attrs)
    |> Repo.insert()
  end

  def delete_edge(edge_id) do
    Repo.get!(FlowEdge, edge_id) |> Repo.delete()
  end

  def bulk_create_edges(flow_id, edges_attrs) do
    Repo.transaction(fn ->
      Enum.map(edges_attrs, fn attrs ->
        {:ok, edge} = create_edge(Map.put(attrs, :flow_id, flow_id))
        edge
      end)
    end)
  end

  # =====================
  # Flow Executions
  # =====================

  def create_execution(attrs) do
    %FlowExecution{}
    |> FlowExecution.changeset(attrs)
    |> Repo.insert()
  end

  def complete_execution(execution_id, attrs) do
    Repo.get!(FlowExecution, execution_id)
    |> FlowExecution.complete_changeset(attrs)
    |> Repo.update()
  end

  def list_executions(opts \\ []) do
    flow_id = Keyword.get(opts, :flow_id)
    status = Keyword.get(opts, :status)
    limit = Keyword.get(opts, :limit, 25)
    offset = Keyword.get(opts, :offset, 0)

    query =
      from e in FlowExecution,
        order_by: [desc: :started_at],
        limit: ^limit,
        offset: ^offset

    query = if flow_id, do: where(query, [e], e.flow_id == ^flow_id), else: query
    query = if status, do: where(query, [e], e.status == ^status), else: query

    Repo.all(query)
  end

  def get_execution!(id) do
    Repo.get!(FlowExecution, id)
  end

  # =====================
  # Flow Global Store
  # =====================

  def get_store_value(flow_id, key) do
    case Repo.one(
           from s in FlowGlobalStore,
             where: s.flow_id == ^flow_id and s.key == ^key,
             where: is_nil(s.expires_at) or s.expires_at > ^DateTime.utc_now()
         ) do
      nil -> nil
      store -> store.value
    end
  end

  def set_store_value(flow_id, key, value, expires_at \\ nil) do
    case Repo.one(from s in FlowGlobalStore, where: s.flow_id == ^flow_id and s.key == ^key) do
      nil ->
        %FlowGlobalStore{}
        |> FlowGlobalStore.changeset(%{flow_id: flow_id, key: key, value: value, expires_at: expires_at})
        |> Repo.insert()

      existing ->
        existing
        |> FlowGlobalStore.changeset(%{value: value, expires_at: expires_at})
        |> Repo.update()
    end
  end

  # =====================
  # Plugin Pages
  # =====================

  def list_published_pages do
    Repo.all(
      from p in PluginPage,
        where: p.is_published == true,
        order_by: [asc: :nav_position, asc: :title]
    )
  end

  def get_page_by_slug!(slug) do
    Repo.get_by!(PluginPage, slug: slug)
  end

  def upsert_page(flow_id, slug, attrs) do
    case Repo.one(from p in PluginPage, where: p.flow_id == ^flow_id and p.slug == ^slug) do
      nil ->
        %PluginPage{}
        |> PluginPage.changeset(Map.merge(attrs, %{flow_id: flow_id, slug: slug}))
        |> Repo.insert()

      existing ->
        existing
        |> PluginPage.changeset(attrs)
        |> Repo.update()
    end
  end

  # =====================
  # Plugin Widgets
  # =====================

  def get_widgets_for_placement(placement) do
    Repo.all(
      from w in PluginWidget,
        where: w.placement == ^placement and w.is_active == true,
        order_by: [asc: :priority]
    )
  end

  def upsert_widget(flow_id, placement, attrs) do
    case Repo.one(from w in PluginWidget, where: w.flow_id == ^flow_id and w.placement == ^placement) do
      nil ->
        %PluginWidget{}
        |> PluginWidget.changeset(Map.merge(attrs, %{flow_id: flow_id, placement: placement}))
        |> Repo.insert()

      existing ->
        existing
        |> PluginWidget.changeset(attrs)
        |> Repo.update()
    end
  end

  # =====================
  # Active Flow Lookup (for Hooks)
  # =====================

  def get_active_flows_for_trigger(trigger_type) do
    Repo.all(
      from f in Flow,
        where: f.status == "active" and f.trigger_type == ^trigger_type,
        preload: [:nodes, :edges]
    )
  end
end
