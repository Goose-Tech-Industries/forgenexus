defmodule ForgeNexus.Plugins.Nodes.Notification.BroadcastMessage do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  require Logger

  @valid_targets ~w(all group online)

  @impl true
  def execute(config, inputs, ctx) do
    message = Map.get(inputs, :message) || Map.get(inputs, "message")
    target = Map.get(config, "target", "all")
    group_id = Map.get(config, "group_id", "")

    payload = %{
      message: message,
      target: target,
      group_id: group_id,
      sent_at: DateTime.utc_now() |> to_string()
    }

    topic =
      case target do
        "group" -> "broadcast:group:#{group_id}"
        "online" -> "broadcast:online"
        _ -> "broadcast:all"
      end

    Logger.info("[PluginFlow] broadcast_message: target=#{target}, topic=#{topic}")

    Phoenix.PubSub.broadcast(
      ForgeNexus.PubSub,
      topic,
      {:broadcast_message, payload}
    )

    # Recipient count would be determined by actual presence tracking
    {:ok, %{recipient_count: 0, success: true}, ctx}
  end

  @impl true
  def validate_config(config) do
    errors = []

    errors =
      case Map.get(config, "target", "all") do
        t when t in @valid_targets -> errors
        _ -> ["target must be one of: #{Enum.join(@valid_targets, ", ")}" | errors]
      end

    errors =
      if Map.get(config, "target") == "group" and Map.get(config, "group_id", "") == "" do
        ["group_id is required when target is group" | errors]
      else
        errors
      end

    if errors == [], do: :ok, else: {:error, errors}
  end

  @impl true
  def schema do
    %{
      type: "notification/broadcast_message",
      category: "notification",
      label: "Broadcast Message",
      description: "Broadcasts a message to all users, a group, or online users via PubSub.",
      inputs: [
        %{name: "message", type: "string", required: true}
      ],
      outputs: [
        %{name: "recipient_count", type: "number"},
        %{name: "success", type: "boolean"}
      ],
      config_fields: [
        %{
          name: "target",
          type: "select",
          options: ~w(all group online),
          default: "all",
          description: "Broadcast target audience"
        },
        %{
          name: "group_id",
          type: "string",
          default: "",
          description: "Group ID (required when target is group)"
        }
      ]
    }
  end
end
