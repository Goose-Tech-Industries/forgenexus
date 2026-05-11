defmodule ForgeNexus.Plugins.Nodes.Stats.GetLevel do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox

  @impl true
  def execute(_config, inputs, ctx) do
    Sandbox.check_db_limit!(ctx)

    user_id = Map.get(inputs, :user_id) || Map.get(inputs, "user_id")

    level = ForgeNexus.UserStats.get_level(user_id)
    ctx = Sandbox.increment_db_ops(ctx)
    {:ok, %{level: level}, ctx}
  end

  @impl true
  def validate_config(config) do
    formula = Map.get(config, "formula", "linear")

    if formula in ~w(linear sqrt exponential) do
      :ok
    else
      {:error, ["formula must be one of: linear, sqrt, exponential"]}
    end
  end

  @impl true
  def schema do
    %{
      type: "stats/get_level",
      category: "stats",
      label: "Get Level",
      description: "Calculates a user's level from their XP using a configurable formula.",
      inputs: [
        %{name: "user_id", type: "string", required: true}
      ],
      outputs: [
        %{name: "level", type: "number"},
        %{name: "current_xp", type: "number"},
        %{name: "xp_for_next", type: "number"},
        %{name: "progress_percent", type: "number"}
      ],
      config_fields: [
        %{name: "xp_stat_key", type: "string", default: "xp", description: "The stat key that stores XP"},
        %{name: "formula", type: "select", options: ~w(linear sqrt exponential), default: "linear", description: "Level calculation formula"}
      ]
    }
  end
end
