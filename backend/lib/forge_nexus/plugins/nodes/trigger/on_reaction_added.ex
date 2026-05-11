defmodule ForgeNexus.Plugins.Nodes.Trigger.OnReactionAdded do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  @impl true
  def execute(_config, _inputs, ctx) do
    td = ctx.trigger_data

    {:ok,
     %{
       reaction: Map.get(td, :reaction, Map.get(td, "reaction")),
       post: Map.get(td, :post, Map.get(td, "post")),
       user: Map.get(td, :user, Map.get(td, "user"))
     }, ctx}
  end

  @impl true
  def validate_config(_config), do: :ok

  @impl true
  def schema do
    %{
      type: "trigger/on_reaction_added",
      category: "trigger",
      label: "On Reaction Added",
      description: "Triggers when a reaction is added to a post.",
      inputs: [],
      outputs: [
        %{name: "reaction", type: "map"},
        %{name: "post", type: "map"},
        %{name: "user", type: "map"}
      ],
      config_fields: []
    }
  end
end
