defmodule ForgeNexus.Plugins.Nodes.Trigger.OnUserJoined do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  @impl true
  def execute(_config, _inputs, ctx) do
    td = ctx.trigger_data
    {:ok, %{user: Map.get(td, :user, Map.get(td, "user"))}, ctx}
  end

  @impl true
  def validate_config(_config), do: :ok

  @impl true
  def schema do
    %{
      type: "trigger/on_user_joined",
      category: "trigger",
      label: "On User Joined",
      description: "Triggers when a new user registers.",
      inputs: [],
      outputs: [%{name: "user", type: "map"}],
      config_fields: []
    }
  end
end
