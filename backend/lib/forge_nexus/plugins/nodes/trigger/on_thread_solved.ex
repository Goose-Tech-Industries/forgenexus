defmodule ForgeNexus.Plugins.Nodes.Trigger.OnThreadSolved do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  @impl true
  def execute(_config, _inputs, ctx) do
    td = ctx.trigger_data

    {:ok,
     %{
       thread: Map.get(td, :thread, Map.get(td, "thread")),
       solver: Map.get(td, :solver, Map.get(td, "solver")),
       marked_by: Map.get(td, :marked_by, Map.get(td, "marked_by"))
     }, ctx}
  end

  @impl true
  def validate_config(_config), do: :ok

  @impl true
  def schema do
    %{
      type: "trigger/on_thread_solved",
      category: "trigger",
      label: "On Thread Solved",
      description: "Triggers when a thread is marked as solved.",
      inputs: [],
      outputs: [
        %{name: "thread", type: "map"},
        %{name: "solver", type: "map"},
        %{name: "marked_by", type: "map"}
      ],
      config_fields: []
    }
  end
end
