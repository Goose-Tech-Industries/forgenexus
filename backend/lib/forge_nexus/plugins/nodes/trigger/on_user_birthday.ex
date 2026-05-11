defmodule ForgeNexus.Plugins.Nodes.Trigger.OnUserBirthday do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  @impl true
  def execute(_config, _inputs, ctx) do
    td = ctx.trigger_data

    {:ok,
     %{
       user: Map.get(td, :user, Map.get(td, "user")),
       age: Map.get(td, :age, Map.get(td, "age"))
     }, ctx}
  end

  @impl true
  def validate_config(_config), do: :ok

  @impl true
  def schema do
    %{
      type: "trigger/on_user_birthday",
      category: "trigger",
      label: "On User Birthday",
      description: "Triggers on a user's birthday. Age may be nil if not provided.",
      inputs: [],
      outputs: [
        %{name: "user", type: "map"},
        %{name: "age", type: "number"}
      ],
      config_fields: []
    }
  end
end
