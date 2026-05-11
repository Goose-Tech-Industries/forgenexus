defmodule ForgeNexus.Plugins.Nodes.Action.SendDm do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  @impl true
  def execute(_config, inputs, ctx) do
    user_id = Map.get(inputs, :user_id) || Map.get(inputs, "user_id")
    body = Map.get(inputs, :body) || Map.get(inputs, "body")

    attrs = %{
      user_id: user_id,
      type: "system_dm",
      title: "Message",
      body: body
    }

    case ForgeNexus.Notifications.create_notification(attrs) do
      {:ok, _} -> {:ok, %{sent: true}, ctx}
      _ -> {:ok, %{sent: false}, ctx}
    end
  end

  @impl true
  def validate_config(_config), do: :ok

  @impl true
  def schema do
    %{
      type: "action/send_dm",
      category: "action",
      label: "Send DM",
      description: "Sends a direct message to a user (delivered as a system notification).",
      inputs: [
        %{name: "user_id", type: "string", required: true},
        %{name: "body", type: "string", required: true}
      ],
      outputs: [%{name: "sent", type: "boolean"}],
      config_fields: []
    }
  end
end
