defmodule ForgeNexus.Plugins.Nodes.Achievement.RevokeBadge do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox

  @impl true
  def execute(_config, inputs, ctx) do
    Sandbox.check_db_limit!(ctx)

    user_id = Map.get(inputs, :user_id) || Map.get(inputs, "user_id")
    badge_id = Map.get(inputs, :badge_id) || Map.get(inputs, "badge_id")

    case ForgeNexus.Achievements.revoke_badge(user_id, badge_id) do
      {:ok, _} ->
        ctx = Sandbox.increment_db_ops(ctx)
        {:ok, %{success: true}, ctx}

      {:error, reason} ->
        ctx = Sandbox.increment_db_ops(ctx)
        {:error, "Failed to revoke badge: #{inspect(reason)}", ctx}
    end
  end

  @impl true
  def validate_config(_config), do: :ok

  @impl true
  def schema do
    %{
      type: "achievement/revoke_badge",
      category: "achievement",
      label: "Revoke Badge",
      description: "Removes a badge from a user.",
      inputs: [
        %{name: "user_id", type: "string", required: true},
        %{name: "badge_id", type: "string", required: true}
      ],
      outputs: [
        %{name: "success", type: "boolean"}
      ],
      config_fields: []
    }
  end
end
