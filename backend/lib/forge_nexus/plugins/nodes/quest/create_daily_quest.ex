defmodule ForgeNexus.Plugins.Nodes.Quest.CreateDailyQuest do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox

  @impl true
  def execute(config, inputs, ctx) do
    Sandbox.check_db_limit!(ctx)

    user_id = Map.get(inputs, :user_id) || Map.get(inputs, "user_id")
    _pool_size = Map.get(config, "pool_size", 3)
    _quest_type = Map.get(config, "quest_type", "daily")

    quests = ForgeNexus.Quests.generate_daily_quests(user_id)
    ctx = Sandbox.increment_db_ops(ctx)
    {:ok, %{quests: quests, count: length(quests)}, ctx}
  end

  @impl true
  def validate_config(config) do
    errors =
      []
      |> then(fn e ->
        ps = Map.get(config, "pool_size")
        if is_nil(ps) or (is_number(ps) and ps > 0), do: e, else: ["pool_size must be a positive number" | e]
      end)

    if errors == [], do: :ok, else: {:error, errors}
  end

  @impl true
  def schema do
    %{
      type: "quest/create_daily_quest",
      category: "quest",
      label: "Create Daily Quest",
      description: "Assigns random daily quests to a user from the available pool.",
      inputs: [
        %{name: "user_id", type: "string", required: true}
      ],
      outputs: [
        %{name: "quests", type: "list"},
        %{name: "count", type: "number"}
      ],
      config_fields: [
        %{name: "pool_size", type: "number", default: 3, description: "Number of daily quests to assign from the pool"},
        %{name: "quest_type", type: "string", default: "daily", description: "Quest type to pull from"}
      ]
    }
  end
end
