defmodule ForgeNexus.Plugins.Nodes.Stats.GetStat do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox

  @impl true
  def execute(_config, inputs, ctx) do
    Sandbox.check_db_limit!(ctx)

    user_id = Map.get(inputs, :user_id) || Map.get(inputs, "user_id")
    stat_key = Map.get(inputs, :stat_key) || Map.get(inputs, "stat_key")

    value = ForgeNexus.UserStats.get_stat(user_id, stat_key)
    ctx = Sandbox.increment_db_ops(ctx)
    {:ok, %{value: value}, ctx}
  end

  @impl true
  def validate_config(_config), do: :ok

  @impl true
  def schema do
    %{
      type: "stats/get_stat",
      category: "stats",
      label: "Get Stat",
      description: "Retrieves a single stat value for a user.",
      inputs: [
        %{name: "user_id", type: "string", required: true},
        %{name: "stat_key", type: "string", required: true}
      ],
      outputs: [
        %{name: "value", type: "number"}
      ],
      config_fields: []
    }
  end
end
