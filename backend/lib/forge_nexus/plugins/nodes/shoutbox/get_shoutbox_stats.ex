defmodule ForgeNexus.Plugins.Nodes.Shoutbox.GetShoutboxStats do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Chat
  alias ForgeNexus.Plugins.Engine.Sandbox

  @impl true
  def execute(_config, _inputs, ctx) do
    Sandbox.check_db_limit!(ctx)

    stats = Chat.shoutbox_stats()

    ctx = Sandbox.increment_db_ops(ctx)

    {:ok,
     %{
       total_messages: stats.total_messages,
       messages_today: stats.messages_today,
       pinned_count: stats.pinned_count
     }, ctx}
  end

  @impl true
  def validate_config(_config), do: :ok

  @impl true
  def schema do
    %{
      type: "shoutbox/get_shoutbox_stats",
      category: "shoutbox",
      label: "Get Shoutbox Stats",
      description:
        "Retrieves shoutbox statistics including total messages, today's count, and pinned count.",
      inputs: [],
      outputs: [
        %{name: "total_messages", type: "number"},
        %{name: "messages_today", type: "number"},
        %{name: "pinned_count", type: "number"}
      ],
      config_fields: []
    }
  end
end
