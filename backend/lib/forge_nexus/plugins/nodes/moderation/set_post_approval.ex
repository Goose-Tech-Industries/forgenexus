defmodule ForgeNexus.Plugins.Nodes.Moderation.SetPostApproval do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox

  @impl true
  def execute(_config, inputs, ctx) do
    Sandbox.check_db_limit!(ctx)
    target_type = Map.get(inputs, :target_type) || Map.get(inputs, "target_type")
    target_id = Map.get(inputs, :target_id) || Map.get(inputs, "target_id")

    require_approval =
      Map.get(inputs, :require_approval) || Map.get(inputs, "require_approval", true)

    case ForgeNexus.Moderation.set_post_approval(target_type, target_id, require_approval) do
      {:ok, _} ->
        ctx = Sandbox.increment_db_ops(ctx)
        {:ok, %{success: true}, ctx}

      {:error, err} ->
        ctx = Sandbox.increment_db_ops(ctx)
        {:error, "Failed to set post approval: #{inspect(err)}", ctx}
    end
  end

  @impl true
  def validate_config(_config), do: :ok

  @impl true
  def schema do
    %{
      type: "moderation/set_post_approval",
      category: "moderation",
      label: "Set Post Approval",
      description: "Enables or disables post approval requirements for a user or forum.",
      inputs: [
        %{name: "target_type", type: "string", required: true},
        %{name: "target_id", type: "string", required: true},
        %{name: "require_approval", type: "boolean", required: true}
      ],
      outputs: [%{name: "success", type: "boolean"}],
      config_fields: []
    }
  end
end
