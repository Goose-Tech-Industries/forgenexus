defmodule ForgeNexus.Plugins.Nodes.Notification.SendAnnouncement do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  require Logger

  @impl true
  def execute(config, inputs, ctx) do
    title = Map.get(inputs, :title) || Map.get(inputs, "title")
    body = Map.get(inputs, :body) || Map.get(inputs, "body")
    channel = Map.get(config, "channel", "")

    Logger.info("[PluginFlow] send_announcement: channel=#{channel}, title=#{inspect(title)}")

    # Broadcast announcement via PubSub to the target channel
    Phoenix.PubSub.broadcast(
      ForgeNexus.PubSub,
      "announcement:#{channel}",
      {:announcement, %{title: title, body: body, channel: channel}}
    )

    {:ok, %{success: true}, ctx}
  end

  @impl true
  def validate_config(config) do
    if Map.get(config, "channel", "") != "",
      do: :ok,
      else: {:error, ["channel is required"]}
  end

  @impl true
  def schema do
    %{
      type: "notification/send_announcement",
      category: "notification",
      label: "Send Announcement",
      description: "Posts an announcement to a forum or chat channel.",
      inputs: [
        %{name: "title", type: "string", required: true},
        %{name: "body", type: "string", required: true}
      ],
      outputs: [
        %{name: "success", type: "boolean"}
      ],
      config_fields: [
        %{
          name: "channel",
          type: "string",
          default: "",
          description: "Forum slug or chat channel to post to"
        }
      ]
    }
  end
end
