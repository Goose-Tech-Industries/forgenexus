defmodule ForgeNexus.Plugins.Nodes.Moderation.UnbanUser do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox

  @impl true
  def execute(_config, inputs, ctx) do
    Sandbox.check_db_limit!(ctx)
    user_id = Map.get(inputs, :user_id) || Map.get(inputs, "user_id")

    case ForgeNexus.Moderation.unban_user_by_id(user_id) do
      {:ok, _} ->
        ctx = Sandbox.increment_db_ops(ctx)
        {:ok, %{success: true}, ctx}

      {:error, err} ->
        ctx = Sandbox.increment_db_ops(ctx)
        {:error, "Failed to unban: #{inspect(err)}", ctx}
    end
  end

  @impl true
  def validate_config(_config), do: :ok

  @impl true
  def schema do
    %{
      type: "moderation/unban_user",
      category: "moderation",
      label: "Unban User",
      description: "Removes a ban from a user, restoring their access.",
      inputs: [%{name: "user_id", type: "string", required: true}],
      outputs: [%{name: "success", type: "boolean"}],
      config_fields: []
    }
  end
end
