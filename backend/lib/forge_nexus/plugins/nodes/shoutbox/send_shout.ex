defmodule ForgeNexus.Plugins.Nodes.Shoutbox.SendShout do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Chat
  alias ForgeNexus.Plugins.Engine.Sandbox

  @impl true
  def execute(_config, inputs, ctx) do
    Sandbox.check_db_limit!(ctx)

    user_id = Map.get(inputs, :user_id) || Map.get(inputs, "user_id")
    body = Map.get(inputs, :body) || Map.get(inputs, "body")

    case Chat.send_shoutbox_message(user_id, body) do
      {:ok, message} ->
        ForgeNexusWeb.Endpoint.broadcast("shoutbox:lobby", "new_message", %{
          id: message.id,
          user_id: message.user_id,
          body: message.body,
          inserted_at: message.inserted_at
        })

        ctx = Sandbox.increment_db_ops(ctx)
        {:ok, %{message_id: message.id, success: true}, ctx}

      {:error, _reason} ->
        ctx = Sandbox.increment_db_ops(ctx)
        {:ok, %{message_id: nil, success: false}, ctx}
    end
  end

  @impl true
  def validate_config(_config), do: :ok

  @impl true
  def schema do
    %{
      type: "shoutbox/send_shout",
      category: "shoutbox",
      label: "Send Shout",
      description: "Sends a message to the shoutbox and broadcasts it in real-time.",
      inputs: [
        %{name: "user_id", type: "string", required: true},
        %{name: "body", type: "string", required: true}
      ],
      outputs: [
        %{name: "message_id", type: "string"},
        %{name: "success", type: "boolean"}
      ],
      config_fields: []
    }
  end
end
