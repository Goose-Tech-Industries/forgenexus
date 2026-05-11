defmodule ForgeNexus.Plugins.Nodes.Trigger.OnChatMessage do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  @impl true
  def execute(_config, _inputs, ctx) do
    td = ctx.trigger_data

    {:ok,
     %{
       message: Map.get(td, :message, Map.get(td, "message")),
       conversation: Map.get(td, :conversation, Map.get(td, "conversation")),
       user: Map.get(td, :user, Map.get(td, "user"))
     }, ctx}
  end

  @impl true
  def validate_config(_config), do: :ok

  @impl true
  def schema do
    %{
      type: "trigger/on_chat_message",
      category: "trigger",
      label: "On Chat Message",
      description: "Triggers when a chat message is sent.",
      inputs: [],
      outputs: [
        %{name: "message", type: "map"},
        %{name: "conversation", type: "map"},
        %{name: "user", type: "map"}
      ],
      config_fields: []
    }
  end
end
