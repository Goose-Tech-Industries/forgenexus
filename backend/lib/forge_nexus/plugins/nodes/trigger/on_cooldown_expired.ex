defmodule ForgeNexus.Plugins.Nodes.Trigger.OnCooldownExpired do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  @impl true
  def execute(_config, _inputs, ctx) do
    td = ctx.trigger_data

    {:ok,
     %{
       user: Map.get(td, :user, Map.get(td, "user")),
       action_key: Map.get(td, :action_key, Map.get(td, "action_key")),
       expired_at: Map.get(td, :expired_at, Map.get(td, "expired_at"))
     }, ctx}
  end

  @impl true
  def validate_config(_config), do: :ok

  @impl true
  def schema do
    %{
      type: "trigger/on_cooldown_expired",
      category: "trigger",
      label: "On Cooldown Expired",
      description: "Triggers when a cooldown timer expires for a user action.",
      inputs: [],
      outputs: [
        %{name: "user", type: "map"},
        %{name: "action_key", type: "string"},
        %{name: "expired_at", type: "string"}
      ],
      config_fields: []
    }
  end
end
