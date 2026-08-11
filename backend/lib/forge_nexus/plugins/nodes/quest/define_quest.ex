defmodule ForgeNexus.Plugins.Nodes.Quest.DefineQuest do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox

  @impl true
  def execute(config, inputs, ctx) do
    Sandbox.check_db_limit!(ctx)
    name = Map.get(inputs, :name) || Map.get(inputs, "name")
    description = Map.get(inputs, :description) || Map.get(inputs, "description")

    attrs = %{
      name: name,
      description: description,
      quest_type: Map.get(config, "quest_type", "side"),
      is_repeatable: Map.get(config, "is_repeatable", false),
      cooldown_hours: Map.get(config, "cooldown_hours", 0),
      reward_points: Map.get(config, "reward_points", 0),
      required_level: Map.get(config, "required_level", 0),
      is_active: true
    }

    quest_changeset =
      %ForgeNexus.Quests.Quest{}
      |> ForgeNexus.Quests.Quest.changeset(attrs)

    case ForgeNexus.Repo.insert(quest_changeset) do
      {:ok, quest} ->
        ctx = Sandbox.increment_db_ops(ctx)
        {:ok, %{quest_id: quest.id, success: true}, ctx}

      {:error, err} ->
        ctx = Sandbox.increment_db_ops(ctx)
        {:error, "Failed to define quest: #{inspect(err)}", ctx}
    end
  end

  @impl true
  def validate_config(config) do
    if Map.get(config, "quest_type", "side") in ~w(main side daily weekly),
      do: :ok,
      else: {:error, ["quest_type must be one of: main, side, daily, weekly"]}
  end

  @impl true
  def schema do
    %{
      type: "quest/define_quest",
      category: "quest",
      label: "Define Quest",
      description: "Defines a new quest with type, rewards, and requirements.",
      inputs: [
        %{name: "name", type: "string", required: true},
        %{name: "description", type: "string", required: false}
      ],
      outputs: [
        %{name: "quest_id", type: "string"},
        %{name: "success", type: "boolean"}
      ],
      config_fields: [
        %{
          name: "quest_type",
          type: "select",
          options: ~w(main side daily weekly),
          default: "side",
          description: "Type of quest"
        },
        %{
          name: "is_repeatable",
          type: "boolean",
          default: false,
          description: "Whether the quest can be repeated"
        },
        %{
          name: "cooldown_hours",
          type: "number",
          default: 0,
          description: "Hours before quest can be repeated"
        },
        %{
          name: "reward_points",
          type: "number",
          default: 0,
          description: "Points awarded on completion"
        },
        %{
          name: "required_level",
          type: "number",
          default: 0,
          description: "Minimum level required to start"
        }
      ]
    }
  end
end
