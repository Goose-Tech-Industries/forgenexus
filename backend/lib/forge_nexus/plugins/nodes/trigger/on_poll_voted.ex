defmodule ForgeNexus.Plugins.Nodes.Trigger.OnPollVoted do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  @impl true
  def execute(_config, _inputs, ctx) do
    td = ctx.trigger_data

    {:ok,
     %{
       user: Map.get(td, :user, Map.get(td, "user")),
       poll: Map.get(td, :poll, Map.get(td, "poll")),
       option: Map.get(td, :option, Map.get(td, "option"))
     }, ctx}
  end

  @impl true
  def validate_config(_config), do: :ok

  @impl true
  def schema do
    %{
      type: "trigger/on_poll_voted",
      category: "trigger",
      label: "On Poll Voted",
      description: "Triggers when a user votes on a poll.",
      inputs: [],
      outputs: [
        %{name: "user", type: "map"},
        %{name: "poll", type: "map"},
        %{name: "option", type: "map"}
      ],
      config_fields: []
    }
  end
end
