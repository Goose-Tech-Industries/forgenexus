defmodule ForgeNexus.Plugins.Nodes.Verification.SendVerificationDm do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox

  @impl true
  def execute(config, inputs, ctx) do
    Sandbox.check_db_limit!(ctx)
    user_id = Map.get(inputs, :user_id) || Map.get(inputs, "user_id")
    message_template = Map.get(config, "message_template", "Welcome! Please verify your account.")

    attrs = %{
      user_id: user_id,
      type: "system",
      title: "Account verification",
      body: message_template
    }

    case ForgeNexus.Notifications.create_notification(attrs) do
      {:ok, _} ->
        ctx = Sandbox.increment_db_ops(ctx)
        {:ok, %{success: true}, ctx}

      {:error, err} ->
        ctx = Sandbox.increment_db_ops(ctx)
        {:error, "Failed to send verification DM: #{inspect(err)}", ctx}
    end
  end

  @impl true
  def validate_config(_config), do: :ok

  @impl true
  def schema do
    %{
      type: "verification/send_verification_dm",
      category: "verification",
      label: "Send Verification DM",
      description: "Sends a direct message to a user with verification instructions.",
      inputs: [%{name: "user_id", type: "string", required: true}],
      outputs: [%{name: "success", type: "boolean"}],
      config_fields: [
        %{
          name: "message_template",
          type: "text",
          default: "Welcome! Please verify your account.",
          description: "Message template to send to the user"
        }
      ]
    }
  end
end
