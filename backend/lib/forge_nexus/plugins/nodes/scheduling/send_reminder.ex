defmodule ForgeNexus.Plugins.Nodes.Scheduling.SendReminder do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox

  @impl true
  def execute(config, inputs, ctx) do
    Sandbox.check_db_limit!(ctx)
    event_id = Map.get(inputs, :event_id) || Map.get(inputs, "event_id")
    minutes_before = Map.get(config, "minutes_before", 60) |> to_number()

    rsvps =
      try do
        ForgeNexus.Events.get_event!(event_id).rsvps || []
      rescue
        _ -> []
      end

    going = Enum.filter(rsvps, fn r -> r.status == "going" end)

    Enum.each(going, fn r ->
      ForgeNexus.Notifications.create_notification(%{
        user_id: r.user_id,
        type: "event_reminder",
        title: "Event reminder",
        body: "Your event starts in #{trunc(minutes_before)} minutes"
      })
    end)

    ctx = Sandbox.increment_db_ops(ctx)
    {:ok, %{reminders_sent: length(going), success: true}, ctx}
  end

  defp to_number(v) when is_number(v), do: v

  defp to_number(v) when is_binary(v) do
    case Float.parse(v) do
      {n, _} -> n
      _ -> 0
    end
  end

  defp to_number(_), do: 0

  @impl true
  def validate_config(_config), do: :ok

  @impl true
  def schema do
    %{
      type: "scheduling/send_reminder",
      category: "scheduling",
      label: "Send Reminder",
      description: "Sends reminder notifications to event attendees.",
      inputs: [%{name: "event_id", type: "string", required: true}],
      outputs: [
        %{name: "reminders_sent", type: "number"},
        %{name: "success", type: "boolean"}
      ],
      config_fields: [
        %{
          name: "minutes_before",
          type: "number",
          default: 60,
          description: "Minutes before event to send reminder"
        }
      ]
    }
  end
end
