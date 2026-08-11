defmodule ForgeNexus.Plugins.Nodes.Shoutbox.SendAnnouncement do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Chat
  alias ForgeNexus.Plugins.Engine.Sandbox

  @impl true
  def execute(config, inputs, ctx) do
    Sandbox.check_db_limit!(ctx)

    user_id = Map.get(inputs, :user_id) || Map.get(inputs, "user_id")
    announcement_text = Map.get(config, "announcement_text", "")

    with {:ok, message} <- Chat.send_shoutbox_message(user_id, announcement_text),
         {:ok, _pinned} <- Chat.pin_shout(message.id) do
      ForgeNexusWeb.Endpoint.broadcast("shoutbox:lobby", "new_message", %{
        id: message.id,
        user_id: message.user_id,
        body: message.body,
        pinned: true,
        inserted_at: message.inserted_at
      })

      ctx = Sandbox.increment_db_ops(ctx)
      ctx = Sandbox.increment_db_ops(ctx)
      {:ok, %{message_id: message.id, success: true}, ctx}
    else
      {:error, _reason} ->
        ctx = Sandbox.increment_db_ops(ctx)
        {:ok, %{message_id: nil, success: false}, ctx}
    end
  end

  @impl true
  def validate_config(config) do
    if Map.has_key?(config, "announcement_text") and
         is_binary(Map.get(config, "announcement_text")) and
         String.length(Map.get(config, "announcement_text")) > 0 do
      :ok
    else
      {:error, ["announcement_text is required"]}
    end
  end

  @impl true
  def schema do
    %{
      type: "shoutbox/send_announcement",
      category: "shoutbox",
      label: "Send Announcement",
      description: "Sends a pinned system-style announcement to the shoutbox.",
      inputs: [
        %{name: "user_id", type: "string", required: true}
      ],
      outputs: [
        %{name: "message_id", type: "string"},
        %{name: "success", type: "boolean"}
      ],
      config_fields: [
        %{
          name: "announcement_text",
          type: "string",
          default: "",
          description: "The announcement message to send and pin"
        }
      ]
    }
  end
end
