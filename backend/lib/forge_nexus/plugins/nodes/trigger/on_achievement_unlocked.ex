defmodule ForgeNexus.Plugins.Nodes.Trigger.OnAchievementUnlocked do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  @impl true
  def execute(_config, _inputs, ctx) do
    td = ctx.trigger_data

    {:ok,
     %{
       user: Map.get(td, :user, Map.get(td, "user")),
       achievement: Map.get(td, :achievement, Map.get(td, "achievement"))
     }, ctx}
  end

  @impl true
  def validate_config(_config), do: :ok

  @impl true
  def schema do
    %{
      type: "trigger/on_achievement_unlocked",
      category: "trigger",
      label: "On Achievement Unlocked",
      description: "Triggers when a user unlocks an achievement.",
      inputs: [],
      outputs: [
        %{name: "user", type: "map"},
        %{name: "achievement", type: "map"}
      ],
      config_fields: []
    }
  end
end
