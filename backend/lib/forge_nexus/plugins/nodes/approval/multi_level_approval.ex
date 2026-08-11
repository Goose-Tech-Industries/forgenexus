defmodule ForgeNexus.Plugins.Nodes.Approval.MultiLevelApproval do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox

  @impl true
  def execute(config, inputs, ctx) do
    Sandbox.check_db_limit!(ctx)
    request_id = Map.get(inputs, :request_id) || Map.get(inputs, "request_id")
    request_data = Map.get(inputs, :request_data) || Map.get(inputs, "request_data", %{})
    approver_levels = Map.get(config, "approver_levels", [])

    approver_levels =
      cond do
        is_list(approver_levels) ->
          approver_levels

        is_binary(approver_levels) ->
          case Jason.decode(approver_levels) do
            {:ok, parsed} when is_list(parsed) -> parsed
            _ -> []
          end

        true ->
          []
      end

    flow_data = Map.get(ctx, :flow_data, %{})
    approval_id = Ecto.UUID.generate()

    approvals_map = Map.get(flow_data, "approvals", %{})

    approval_record = %{
      "id" => approval_id,
      "request_id" => request_id,
      "request_data" => request_data,
      "approver_levels" => approver_levels,
      "current_level" => 1,
      "status" => "pending",
      "created_at" => DateTime.utc_now() |> DateTime.to_iso8601()
    }

    flow_data =
      Map.put(flow_data, "approvals", Map.put(approvals_map, approval_id, approval_record))

    ctx = Map.put(ctx, :flow_data, flow_data)
    ctx = Sandbox.increment_db_ops(ctx)

    {:ok, %{approval_id: approval_id, current_level: 1, success: true}, ctx}
  end

  @impl true
  def validate_config(config) do
    case Map.get(config, "approver_levels") do
      nil ->
        {:error, ["approver_levels is required"]}

      levels when is_list(levels) and length(levels) > 0 ->
        :ok

      levels when is_binary(levels) ->
        case Jason.decode(levels) do
          {:ok, parsed} when is_list(parsed) and length(parsed) > 0 -> :ok
          _ -> {:error, ["approver_levels must be a JSON list of user_ids or group_ids"]}
        end

      _ ->
        {:error, ["approver_levels must be a JSON list of user_ids or group_ids"]}
    end
  end

  @impl true
  def schema do
    %{
      type: "approval/multi_level_approval",
      category: "approval",
      label: "Multi-Level Approval",
      description:
        "Creates a multi-level approval request that must pass through sequential approver tiers.",
      inputs: [
        %{name: "request_id", type: "string", required: true},
        %{name: "request_data", type: "map", required: true}
      ],
      outputs: [
        %{name: "approval_id", type: "string"},
        %{name: "current_level", type: "number"},
        %{name: "success", type: "boolean"}
      ],
      config_fields: [
        %{
          name: "approver_levels",
          type: "json",
          default: [],
          description: "JSON list of approver user_ids or group_ids (one per level)"
        }
      ]
    }
  end
end
