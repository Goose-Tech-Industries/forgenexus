defmodule ForgeNexus.Plugins.Nodes.Moderation.TimeoutUser do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox

  @impl true
  def execute(_config, inputs, ctx) do
    Sandbox.check_db_limit!(ctx)
    user_id = Map.get(inputs, :user_id) || Map.get(inputs, "user_id")
    duration = Map.get(inputs, :duration_seconds) || Map.get(inputs, "duration_seconds") || 0
    duration = if is_integer(duration), do: duration, else: trunc(duration / 1)
    reason = Map.get(inputs, :reason) || Map.get(inputs, "reason", "")

    case ForgeNexus.Moderation.timeout_user_seconds(user_id, duration, reason) do
      {:ok, _} ->
        ctx = Sandbox.increment_db_ops(ctx)
        {:ok, %{success: true}, ctx}

      {:error, err} ->
        ctx = Sandbox.increment_db_ops(ctx)
        {:error, "Failed to timeout user: #{inspect(err)}", ctx}
    end
  end

  @impl true
  def validate_config(_config), do: :ok

  @impl true
  def schema do
    %{
      type: "moderation/timeout_user",
      category: "moderation",
      label: "Timeout User",
      description: "Temporarily restricts a user for a specified duration.",
      inputs: [
        %{name: "user_id", type: "string", required: true},
        %{name: "duration_seconds", type: "number", required: true},
        %{name: "reason", type: "string", required: false}
      ],
      outputs: [%{name: "success", type: "boolean"}],
      config_fields: []
    }
  end
end
