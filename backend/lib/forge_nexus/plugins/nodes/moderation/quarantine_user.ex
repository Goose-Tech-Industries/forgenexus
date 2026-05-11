defmodule ForgeNexus.Plugins.Nodes.Moderation.QuarantineUser do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox

  @impl true
  def execute(_config, inputs, ctx) do
    Sandbox.check_db_limit!(ctx)
    user_id = Map.get(inputs, :user_id) || Map.get(inputs, "user_id")
    reason = Map.get(inputs, :reason) || Map.get(inputs, "reason", "")

    case ForgeNexus.Moderation.quarantine_user(user_id, reason) do
      {:ok, _} ->
        ctx = Sandbox.increment_db_ops(ctx)
        {:ok, %{success: true}, ctx}

      {:error, err} ->
        ctx = Sandbox.increment_db_ops(ctx)
        {:error, "Failed to quarantine: #{inspect(err)}", ctx}
    end
  end

  @impl true
  def validate_config(_config), do: :ok

  @impl true
  def schema do
    %{
      type: "moderation/quarantine_user",
      category: "moderation",
      label: "Quarantine User",
      description: "Places a user into a restricted group pending moderator review.",
      inputs: [
        %{name: "user_id", type: "string", required: true},
        %{name: "reason", type: "string", required: false}
      ],
      outputs: [%{name: "success", type: "boolean"}],
      config_fields: []
    }
  end
end
