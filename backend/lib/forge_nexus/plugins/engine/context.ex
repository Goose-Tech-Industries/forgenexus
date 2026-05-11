defmodule ForgeNexus.Plugins.Engine.Context do
  @moduledoc """
  Execution context that flows through every node in a plugin flow.
  Tracks variables, resource usage, and trace data.
  """

  @type t :: %__MODULE__{}

  defstruct [
    :execution_id,
    :flow_id,
    :trigger_data,
    :triggered_by_id,
    variables: %{},
    node_trace: [],
    nodes_executed: 0,
    db_operations: 0,
    http_requests: 0,
    loop_iterations: 0,
    started_at: nil,
    max_nodes: 200,
    max_db_ops: 50,
    max_http_requests: 5,
    max_loop_iterations: 1000,
    timeout_ms: 30_000
  ]
end
