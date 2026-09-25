defmodule ForgeNexus.Plugins.Nodes.Shoutbox.ClearShoutbox do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Chat
  alias ForgeNexus.Plugins.Engine.Sandbox

  @impl true
  def execute(_config, _inputs, ctx) do
    Sandbox.check_db_limit!(ctx)

    {:ok, count} = Chat.clear_shoutbox()
    ForgeNexusWeb.Endpoint.broadcast("shoutbox:lobby", "shoutbox_cleared", %{})

    ctx = Sandbox.increment_db_ops(ctx)
    {:ok, %{messages_cleared: count, success: true}, ctx}
  end

  @impl true
  def validate_config(_config), do: :ok

  @impl true
  def schema do
    %{
      type: "shoutbox/clear_shoutbox",
      category: "shoutbox",
      label: "Clear Shoutbox",
      description: "Deletes all messages from the shoutbox.",
      inputs: [],
      outputs: [
        %{name: "messages_cleared", type: "number"},
        %{name: "success", type: "boolean"}
      ],
      config_fields: []
    }
  end
end
