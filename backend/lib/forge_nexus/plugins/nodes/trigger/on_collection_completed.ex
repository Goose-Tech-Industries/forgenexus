defmodule ForgeNexus.Plugins.Nodes.Trigger.OnCollectionCompleted do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  @impl true
  def execute(_config, _inputs, ctx) do
    td = ctx.trigger_data

    {:ok,
     %{
       user: Map.get(td, :user, Map.get(td, "user")),
       collection_set: Map.get(td, :collection_set, Map.get(td, "collection_set"))
     }, ctx}
  end

  @impl true
  def validate_config(_config), do: :ok

  @impl true
  def schema do
    %{
      type: "trigger/on_collection_completed",
      category: "trigger",
      label: "On Collection Completed",
      description: "Triggers when a user completes a collection set.",
      inputs: [],
      outputs: [
        %{name: "user", type: "map"},
        %{name: "collection_set", type: "map"}
      ],
      config_fields: []
    }
  end
end
