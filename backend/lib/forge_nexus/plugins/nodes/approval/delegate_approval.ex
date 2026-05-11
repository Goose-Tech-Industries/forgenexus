defmodule ForgeNexus.Plugins.Nodes.Approval.DelegateApproval do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox

  @impl true
  def execute(_config, inputs, ctx) do
    Sandbox.check_db_limit!(ctx)
    approval_id = Map.get(inputs, :approval_id) || Map.get(inputs, "approval_id")
    new_approver_id = Map.get(inputs, :new_approver_id) || Map.get(inputs, "new_approver_id")

    flow_data = Map.get(ctx, :flow_data, %{})
    approvals = Map.get(flow_data, "approvals", %{})

    case Map.get(approvals, approval_id) do
      nil ->
        ctx = Sandbox.increment_db_ops(ctx)
        {:error, "Approval not found: #{approval_id}", ctx}

      record ->
        updated = Map.put(record, "delegated_to", new_approver_id)
        approvals = Map.put(approvals, approval_id, updated)
        flow_data = Map.put(flow_data, "approvals", approvals)
        ctx = Map.put(ctx, :flow_data, flow_data)
        ctx = Sandbox.increment_db_ops(ctx)
        {:ok, %{success: true}, ctx}
    end
  end

  @impl true
  def validate_config(_config), do: :ok

  @impl true
  def schema do
    %{
      type: "approval/delegate_approval",
      category: "approval",
      label: "Delegate Approval",
      description: "Delegates an approval request to a different approver.",
      inputs: [
        %{name: "approval_id", type: "string", required: true},
        %{name: "new_approver_id", type: "string", required: true}
      ],
      outputs: [%{name: "success", type: "boolean"}],
      config_fields: []
    }
  end
end
