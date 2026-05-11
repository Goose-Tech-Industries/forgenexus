defmodule ForgeNexus.Plugins.Engine.Executor do
  @moduledoc """
  Core runtime that executes plugin flows by walking the node graph.
  """

  alias ForgeNexus.Repo
  alias ForgeNexus.Plugins.{Flow, FlowExecution}
  alias ForgeNexus.Plugins.Engine.{Context, Sandbox, SandboxError}
  alias ForgeNexus.Plugins.Nodes.Registry

  import Ecto.Query

  require Logger

  @doc """
  Main entry point. Loads a flow and executes it with the given trigger data.
  """
  def execute_flow(flow_id, trigger_data, triggered_by_id \\ nil) do
    Sandbox.check_rate_limit!(flow_id)

    flow = Repo.get!(Flow, flow_id) |> Repo.preload([:nodes, :edges])
    started_at = DateTime.utc_now()

    execution =
      %FlowExecution{}
      |> FlowExecution.changeset(%{
        flow_id: flow_id,
        trigger_type: flow.trigger_type,
        trigger_data: trigger_data,
        started_at: started_at,
        triggered_by_id: triggered_by_id
      })
      |> Repo.insert!()

    ctx = %Context{
      execution_id: execution.id,
      flow_id: flow_id,
      trigger_data: trigger_data,
      triggered_by_id: triggered_by_id,
      started_at: started_at
    }

    nodes_map = Map.new(flow.nodes, fn n -> {n.id, n} end)

    edges_by_source =
      flow.edges
      |> Enum.group_by(& &1.source_node_id)

    # Find the trigger node (entry point)
    trigger_node =
      flow.nodes
      |> Enum.find(fn n -> String.starts_with?(n.type, "trigger/") end)

    task =
      Task.async(fn ->
        try do
          case trigger_node do
            nil ->
              {:error, "No trigger node found in flow", ctx}

            node ->
              run_graph(node, nodes_map, edges_by_source, ctx)
          end
        rescue
          e in SandboxError ->
            {:error, e.message, ctx}

          e ->
            {:error, Exception.message(e), ctx}
        catch
          :exit, reason ->
            {:error, "Flow crashed: #{inspect(reason)}", ctx}
        end
      end)

    result =
      try do
        Task.await(task, ctx.timeout_ms + 1000)
      catch
        :exit, {:timeout, _} ->
          Task.shutdown(task, :brutal_kill)
          {:error, "Flow execution timed out", ctx}
      end

    finish_execution(execution, result)
  end

  @doc """
  Recursive graph walker. Executes a node, then follows edges to next nodes.
  """
  def run_graph(current_node, nodes_map, edges_by_source, ctx) do
    Sandbox.check_node_limit!(ctx)
    Sandbox.check_timeout!(ctx)

    ctx = Sandbox.increment_nodes(ctx)

    {:ok, handler} =
      case Registry.get_handler(current_node.type) do
        {:ok, mod} -> {:ok, mod}
        {:error, :unknown_node_type} -> raise "Unknown node type: #{current_node.type}"
      end

    inputs = resolve_inputs(current_node, ctx, edges_by_source, nodes_map)
    config = current_node.config || %{}

    trace_start = System.monotonic_time(:microsecond)

    result = handler.execute(config, inputs, ctx)

    trace_duration = System.monotonic_time(:microsecond) - trace_start

    {status, output, ctx} =
      case result do
        {:ok, output, new_ctx} -> {"ok", output, new_ctx}
        {:error, msg, new_ctx} -> {"error", %{error: msg}, new_ctx}
        {:branch, port, output, new_ctx} -> {"branch:#{port}", output, new_ctx}
      end

    trace_entry = %{
      node_id: current_node.id,
      node_type: current_node.type,
      label: current_node.label,
      status: status,
      duration_us: trace_duration,
      timestamp: DateTime.utc_now()
    }

    ctx = %{ctx | node_trace: ctx.node_trace ++ [trace_entry]}

    # Store output in variables
    ctx = %{ctx | variables: Map.put(ctx.variables, current_node.id, output)}

    # If error, stop execution
    case result do
      {:error, _, _} ->
        result

      {:ok, _, _} ->
        follow_edges(current_node.id, "output", nodes_map, edges_by_source, ctx)

      {:branch, port, _, _} ->
        follow_edges(current_node.id, port, nodes_map, edges_by_source, ctx)
    end
  end

  defp follow_edges(source_id, port, nodes_map, edges_by_source, ctx) do
    edges = Map.get(edges_by_source, source_id, [])

    matching_edges =
      Enum.filter(edges, fn edge ->
        edge.source_port == port
      end)

    case matching_edges do
      [] ->
        # Terminal node — return last result
        {:ok, Map.get(ctx.variables, source_id, %{}), ctx}

      edges ->
        Enum.reduce(edges, {:ok, %{}, ctx}, fn edge, {_status, _out, acc_ctx} ->
          case Map.get(nodes_map, edge.target_node_id) do
            nil ->
              {:error, "Edge references missing node: #{edge.target_node_id}", acc_ctx}

            next_node ->
              run_graph(next_node, nodes_map, edges_by_source, acc_ctx)
          end
        end)
    end
  end

  @doc """
  Gathers inputs for a node from context.variables based on incoming edges.
  """
  def resolve_inputs(node, ctx, edges_by_source, _nodes_map) do
    # Find all edges targeting this node
    all_edges =
      edges_by_source
      |> Enum.flat_map(fn {_source_id, edges} -> edges end)
      |> Enum.filter(fn edge -> edge.target_node_id == node.id end)

    # For each incoming edge, get the source node's output
    Enum.reduce(all_edges, %{}, fn edge, acc ->
      source_output = Map.get(ctx.variables, edge.source_node_id, %{})
      Map.merge(acc, source_output)
    end)
  end

  defp finish_execution(execution, result) do
    now = DateTime.utc_now()

    {status, final_result, ctx} =
      case result do
        {:ok, output, ctx} -> {"completed", output, ctx}
        {:error, msg, ctx} -> {"failed", %{error: msg}, ctx}
        {:branch, _port, output, ctx} -> {"completed", output, ctx}
      end

    duration_ms = DateTime.diff(now, execution.started_at, :millisecond)

    execution
    |> FlowExecution.complete_changeset(%{
      status: status,
      result: final_result,
      node_trace: ctx.node_trace,
      finished_at: now,
      duration_ms: duration_ms,
      nodes_executed: ctx.nodes_executed,
      db_operations: ctx.db_operations,
      http_requests: ctx.http_requests
    })
    |> Repo.update!()

    # Update the flow's execution stats
    from(f in Flow, where: f.id == ^ctx.flow_id)
    |> Repo.update_all(set: [last_executed_at: now], inc: [execution_count: 1])

    {String.to_atom(status), final_result}
  end
end
