defmodule ForgeNexus.Plugins.Nodes.Action.SendNotification do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  @impl true
  def execute(_config, inputs, ctx) do
    user_id = Map.get(inputs, :user_id) || Map.get(inputs, "user_id")
    title = Map.get(inputs, :title) || Map.get(inputs, "title")
    body = Map.get(inputs, :body) || Map.get(inputs, "body")
    link = Map.get(inputs, :link) || Map.get(inputs, "link")

    attrs = %{
      user_id: user_id,
      type: "system",
      title: title,
      body: body,
      link: link
    }

    case ForgeNexus.Notifications.create_notification(attrs) do
      {:ok, _} -> {:ok, %{sent: true}, ctx}
      {:error, _} -> {:ok, %{sent: false}, ctx}
    end
  end

  @impl true
  def validate_config(_config), do: :ok

  @impl true
  def schema do
    %{
      type: "action/send_notification",
      category: "action",
      label: "Send Notification",
      description: "Sends a notification to a user.",
      inputs: [
        %{name: "user_id", type: "string", required: true},
        %{name: "title", type: "string", required: true},
        %{name: "body", type: "string", required: true},
        %{name: "link", type: "string", required: false}
      ],
      outputs: [%{name: "sent", type: "boolean"}],
      config_fields: []
    }
  end
end
