defmodule ForgeNexus.Plugins.Nodes.Approval.AutoApproveOnTimeout do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox

  @impl true
  def execute(config, inputs, ctx) do
    Sandbox.check_db_limit!(ctx)
    approval_id = Map.get(inputs, :approval_id) || Map.get(inputs, "approval_id")
    timeout_hours = Map.get(config, "timeout_hours", 48) |> to_number()

    flow_data = Map.get(ctx, :flow_data, %{})
    approvals = Map.get(flow_data, "approvals", %{})

    {hours_elapsed, was_auto_approved, ctx2} =
      case Map.get(approvals, approval_id) do
        nil ->
          {0.0, false, ctx}

        record ->
          created_iso = Map.get(record, "created_at")

          hours =
            case created_iso && DateTime.from_iso8601(created_iso) do
              {:ok, dt, _} -> DateTime.diff(DateTime.utc_now(), dt) / 3600.0
              _ -> 0.0
            end

          if hours >= timeout_hours do
            updated = Map.put(record, "status", "auto_approved")
            new_approvals = Map.put(approvals, approval_id, updated)
            new_flow = Map.put(flow_data, "approvals", new_approvals)
            {hours, true, Map.put(ctx, :flow_data, new_flow)}
          else
            {hours, false, ctx}
          end
      end

    ctx2 = Sandbox.increment_db_ops(ctx2)
    {:ok, %{was_auto_approved: was_auto_approved, hours_elapsed: Float.round(hours_elapsed, 2)}, ctx2}
  end

  defp to_number(v) when is_number(v), do: v

  defp to_number(v) when is_binary(v) do
    case Float.parse(v) do
      {n, _} -> n
      _ -> 0
    end
  end

  defp to_number(_), do: 0

  @impl true
  def validate_config(config) do
    case Map.get(config, "timeout_hours") do
      nil ->
        :ok

      val when is_number(val) and val > 0 ->
        :ok

      val when is_binary(val) ->
        case Float.parse(val) do
          {n, _} when n > 0 -> :ok
          _ -> {:error, ["timeout_hours must be a positive number"]}
        end

      _ ->
        {:error, ["timeout_hours must be a positive number"]}
    end
  end

  @impl true
  def schema do
    %{
      type: "approval/auto_approve_on_timeout",
      category: "approval",
      label: "Auto-Approve on Timeout",
      description: "Checks if an approval request has exceeded its timeout and auto-approves if so.",
      inputs: [%{name: "approval_id", type: "string", required: true}],
      outputs: [
        %{name: "was_auto_approved", type: "boolean"},
        %{name: "hours_elapsed", type: "number"}
      ],
      config_fields: [
        %{name: "timeout_hours", type: "number", default: 48, description: "Hours before auto-approval kicks in"}
      ]
    }
  end
end
