defmodule ForgeNexus.Plugins.Nodes.Notification.ChannelNotification do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  require Logger

  @impl true
  def execute(config, inputs, ctx) do
    channel_id = Map.get(inputs, :channel_id) || Map.get(inputs, "channel_id")
    message = Map.get(inputs, :message) || Map.get(inputs, "message")
    is_embed = Map.get(config, "is_embed", false)

    payload = %{
      message: message,
      is_embed: is_embed,
      sent_at: DateTime.utc_now() |> to_string()
    }

    Logger.info("[PluginFlow] channel_notification: channel=#{channel_id}, embed=#{is_embed}")

    Phoenix.PubSub.broadcast(
      ForgeNexus.PubSub,
      "chat:#{channel_id}",
      {:plugin_message, payload}
    )

    {:ok, %{message_id: nil, success: true}, ctx}
  end

  @impl true
  def validate_config(_config), do: :ok

  @impl true
  def schema do
    %{
      type: "notification/channel_notification",
      category: "notification",
      label: "Channel Notification",
      description: "Sends a notification message to a chat channel via PubSub.",
      inputs: [
        %{name: "channel_id", type: "string", required: true},
        %{name: "message", type: "string", required: true}
      ],
      outputs: [
        %{name: "message_id", type: "string"},
        %{name: "success", type: "boolean"}
      ],
      config_fields: [
        %{name: "is_embed", type: "boolean", default: false, description: "Display as rich embed"}
      ]
    }
  end
end
