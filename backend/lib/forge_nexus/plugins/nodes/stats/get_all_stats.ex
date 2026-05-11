defmodule ForgeNexus.Plugins.Nodes.Stats.GetAllStats do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox

  @impl true
  def execute(_config, inputs, ctx) do
    Sandbox.check_db_limit!(ctx)

    user_id = Map.get(inputs, :user_id) || Map.get(inputs, "user_id")

    stats = ForgeNexus.UserStats.get_all_stats(user_id)
    ctx = Sandbox.increment_db_ops(ctx)
    {:ok, %{stats: stats, count: map_size(stats)}, ctx}
  end

  @impl true
  def validate_config(_config), do: :ok

  @impl true
  def schema do
    %{
      type: "stats/get_all_stats",
      category: "stats",
      label: "Get All Stats",
      description: "Retrieves all stat key-value pairs for a user.",
      inputs: [
        %{name: "user_id", type: "string", required: true}
      ],
      outputs: [
        %{name: "stats", type: "map"},
        %{name: "count", type: "number"}
      ],
      config_fields: []
    }
  end
end
