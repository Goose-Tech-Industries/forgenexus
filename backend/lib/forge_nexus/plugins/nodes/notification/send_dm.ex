defmodule ForgeNexus.Plugins.Nodes.Notification.SendDm do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox
  alias ForgeNexus.Accounts.User
  alias ForgeNexus.Repo

  @impl true
  def execute(config, inputs, ctx) do
    Sandbox.check_db_limit!(ctx)
    user_id = Map.get(inputs, :user_id) || Map.get(inputs, "user_id")
    body = Map.get(inputs, :body) || Map.get(inputs, "body")
    from_system = Map.get(config, "from_system", true)

    case Repo.get(User, user_id) do
      nil ->
        ctx = Sandbox.increment_db_ops(ctx)
        {:error, "User not found: #{user_id}", ctx}

      _user ->
        type = if from_system, do: "system_dm", else: "dm"

        result =
          ForgeNexus.Notifications.create_notification(%{
            user_id: user_id,
            type: type,
            title: "Message",
            body: body
          })

        ctx = Sandbox.increment_db_ops(ctx)

        case result do
          {:ok, n} -> {:ok, %{conversation_id: n.id, success: true}, ctx}
          {:error, err} -> {:error, "Failed to send DM: #{inspect(err)}", ctx}
        end
    end
  end

  @impl true
  def validate_config(_config), do: :ok

  @impl true
  def schema do
    %{
      type: "notification/send_dm",
      category: "notification",
      label: "Send DM",
      description: "Sends a direct message to a user, optionally from the system account.",
      inputs: [
        %{name: "user_id", type: "string", required: true},
        %{name: "body", type: "string", required: true}
      ],
      outputs: [
        %{name: "conversation_id", type: "string"},
        %{name: "success", type: "boolean"}
      ],
      config_fields: [
        %{
          name: "from_system",
          type: "boolean",
          default: true,
          description: "Send as system message"
        }
      ]
    }
  end
end
