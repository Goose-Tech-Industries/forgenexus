defmodule ForgeNexus.Plugins.Nodes.Trigger.OnThreadCreated do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  @impl true
  def execute(_config, _inputs, ctx) do
    td = ctx.trigger_data

    {:ok,
     %{
       thread: Map.get(td, :thread, Map.get(td, "thread")),
       user: Map.get(td, :user, Map.get(td, "user")),
       forum: Map.get(td, :forum, Map.get(td, "forum"))
     }, ctx}
  end

  @impl true
  def validate_config(_config), do: :ok

  @impl true
  def schema do
    %{
      type: "trigger/on_thread_created",
      category: "trigger",
      label: "On Thread Created",
      description: "Triggers when a new thread is created.",
      inputs: [],
      outputs: [
        %{name: "thread", type: "map"},
        %{name: "user", type: "map"},
        %{name: "forum", type: "map"}
      ],
      config_fields: []
    }
  end
end
