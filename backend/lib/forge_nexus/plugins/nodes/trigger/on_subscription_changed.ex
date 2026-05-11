defmodule ForgeNexus.Plugins.Nodes.Trigger.OnSubscriptionChanged do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  @impl true
  def execute(_config, _inputs, ctx) do
    td = ctx.trigger_data

    {:ok,
     %{
       user: Map.get(td, :user, Map.get(td, "user")),
       old_tier: Map.get(td, :old_tier, Map.get(td, "old_tier")),
       new_tier: Map.get(td, :new_tier, Map.get(td, "new_tier")),
       change_type: Map.get(td, :change_type, Map.get(td, "change_type"))
     }, ctx}
  end

  @impl true
  def validate_config(_config), do: :ok

  @impl true
  def schema do
    %{
      type: "trigger/on_subscription_changed",
      category: "trigger",
      label: "On Subscription Changed",
      description:
        "Triggers when a user's subscription changes (upgrade, downgrade, cancel, or new).",
      inputs: [],
      outputs: [
        %{name: "user", type: "map"},
        %{name: "old_tier", type: "map"},
        %{name: "new_tier", type: "map"},
        %{name: "change_type", type: "string"}
      ],
      config_fields: []
    }
  end
end
