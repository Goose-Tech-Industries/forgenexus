defmodule ForgeNexus.Plugins.Nodes.Trigger.OnUserBanned do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  @impl true
  def execute(_config, _inputs, ctx) do
    td = ctx.trigger_data

    {:ok,
     %{
       user: Map.get(td, :user, Map.get(td, "user")),
       banned_by: Map.get(td, :banned_by, Map.get(td, "banned_by")),
       reason: Map.get(td, :reason, Map.get(td, "reason")),
       duration: Map.get(td, :duration, Map.get(td, "duration"))
     }, ctx}
  end

  @impl true
  def validate_config(_config), do: :ok

  @impl true
  def schema do
    %{
      type: "trigger/on_user_banned",
      category: "trigger",
      label: "On User Banned",
      description: "Triggers when a user is banned. Duration is nil if permanent.",
      inputs: [],
      outputs: [
        %{name: "user", type: "map"},
        %{name: "banned_by", type: "map"},
        %{name: "reason", type: "string"},
        %{name: "duration", type: "number"}
      ],
      config_fields: []
    }
  end
end
