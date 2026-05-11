defmodule ForgeNexus.Plugins.Engine.SandboxError do
  defexception [:message]
end

defmodule ForgeNexus.Plugins.Engine.Sandbox do
  @moduledoc """
  Resource enforcement for plugin flow execution.
  Prevents runaway flows from consuming excessive resources.
  """

  alias ForgeNexus.Plugins.Engine.{Context, SandboxError}
  alias ForgeNexus.Plugins.FlowRateLimit
  alias ForgeNexus.Repo

  import Ecto.Query

  @max_executions_per_hour 100

  def check_node_limit!(%Context{nodes_executed: n, max_nodes: max}) when n >= max do
    raise SandboxError, "Node execution limit reached (#{max})"
  end

  def check_node_limit!(_ctx), do: :ok

  def check_db_limit!(%Context{db_operations: n, max_db_ops: max}) when n >= max do
    raise SandboxError, "Database operation limit reached (#{max})"
  end

  def check_db_limit!(_ctx), do: :ok

  def check_http_limit!(%Context{http_requests: n, max_http_requests: max}) when n >= max do
    raise SandboxError, "HTTP request limit reached (#{max})"
  end

  def check_http_limit!(_ctx), do: :ok

  def check_loop_limit!(%Context{loop_iterations: n, max_loop_iterations: max}) when n >= max do
    raise SandboxError, "Loop iteration limit reached (#{max})"
  end

  def check_loop_limit!(_ctx), do: :ok

  def check_timeout!(%Context{started_at: started_at, timeout_ms: timeout_ms}) do
    elapsed = DateTime.diff(DateTime.utc_now(), started_at, :millisecond)

    if elapsed >= timeout_ms do
      raise SandboxError, "Flow execution timed out after #{timeout_ms}ms"
    end

    :ok
  end

  def increment_nodes(%Context{} = ctx) do
    %{ctx | nodes_executed: ctx.nodes_executed + 1}
  end

  def increment_db_ops(%Context{} = ctx) do
    %{ctx | db_operations: ctx.db_operations + 1}
  end

  def increment_http_requests(%Context{} = ctx) do
    %{ctx | http_requests: ctx.http_requests + 1}
  end

  def increment_loop_iterations(%Context{} = ctx) do
    %{ctx | loop_iterations: ctx.loop_iterations + 1}
  end

  def check_rate_limit!(flow_id) do
    now = DateTime.utc_now()
    window_start = now |> DateTime.truncate(:second) |> Map.put(:minute, 0) |> Map.put(:second, 0)

    result =
      from(r in FlowRateLimit,
        where: r.flow_id == ^flow_id and r.window_start == ^window_start
      )
      |> Repo.one()

    case result do
      nil ->
        %FlowRateLimit{}
        |> FlowRateLimit.changeset(%{
          flow_id: flow_id,
          window_start: window_start,
          execution_count: 1
        })
        |> Repo.insert!(on_conflict: :nothing)

        :ok

      %FlowRateLimit{execution_count: count} when count >= @max_executions_per_hour ->
        raise SandboxError,
              "Rate limit exceeded: #{count} executions this hour (max #{@max_executions_per_hour})"

      %FlowRateLimit{} = record ->
        from(r in FlowRateLimit, where: r.id == ^record.id)
        |> Repo.update_all(inc: [execution_count: 1])

        :ok
    end
  end
end
