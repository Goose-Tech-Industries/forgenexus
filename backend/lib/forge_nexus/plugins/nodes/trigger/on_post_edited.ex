defmodule ForgeNexus.Plugins.Nodes.Trigger.OnPostEdited do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  @impl true
  def execute(_config, _inputs, ctx) do
    td = ctx.trigger_data

    {:ok,
     %{
       post: Map.get(td, :post, Map.get(td, "post")),
       user: Map.get(td, :user, Map.get(td, "user")),
       old_body: Map.get(td, :old_body, Map.get(td, "old_body")),
       new_body: Map.get(td, :new_body, Map.get(td, "new_body")),
       thread: Map.get(td, :thread, Map.get(td, "thread"))
     }, ctx}
  end

  @impl true
  def validate_config(_config), do: :ok

  @impl true
  def schema do
    %{
      type: "trigger/on_post_edited",
      category: "trigger",
      label: "On Post Edited",
      description: "Triggers when a post is edited.",
      inputs: [],
      outputs: [
        %{name: "post", type: "map"},
        %{name: "user", type: "map"},
        %{name: "old_body", type: "string"},
        %{name: "new_body", type: "string"},
        %{name: "thread", type: "map"}
      ],
      config_fields: []
    }
  end
end
