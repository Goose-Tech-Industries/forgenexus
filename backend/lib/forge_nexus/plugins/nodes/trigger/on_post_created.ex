defmodule ForgeNexus.Plugins.Nodes.Trigger.OnPostCreated do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  @impl true
  def execute(_config, _inputs, ctx) do
    td = ctx.trigger_data

    {:ok,
     %{
       post: Map.get(td, :post, Map.get(td, "post")),
       thread: Map.get(td, :thread, Map.get(td, "thread")),
       user: Map.get(td, :user, Map.get(td, "user"))
     }, ctx}
  end

  @impl true
  def validate_config(_config), do: :ok

  @impl true
  def schema do
    %{
      type: "trigger/on_post_created",
      category: "trigger",
      label: "On Post Created",
      description: "Triggers when a new post is created.",
      inputs: [],
      outputs: [
        %{name: "post", type: "map"},
        %{name: "thread", type: "map"},
        %{name: "user", type: "map"}
      ],
      config_fields: []
    }
  end
end
