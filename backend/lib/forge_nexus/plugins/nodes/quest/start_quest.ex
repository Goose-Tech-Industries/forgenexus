defmodule ForgeNexus.Plugins.Nodes.Quest.StartQuest do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox

  @impl true
  def execute(_config, inputs, ctx) do
    Sandbox.check_db_limit!(ctx)

    user_id = Map.get(inputs, :user_id) || Map.get(inputs, "user_id")
    quest_id = Map.get(inputs, :quest_id) || Map.get(inputs, "quest_id")

    case ForgeNexus.Quests.start_quest(user_id, quest_id) do
      {:ok, user_quest} ->
        ctx = Sandbox.increment_db_ops(ctx)

        {:ok,
         %{
           user_quest_id: user_quest.id,
           success: true,
           first_step: user_quest.first_step
         }, ctx}

      {:error, reason} ->
        ctx = Sandbox.increment_db_ops(ctx)
        {:error, "Failed to start quest: #{inspect(reason)}", ctx}
    end
  end

  @impl true
  def validate_config(_config), do: :ok

  @impl true
  def schema do
    %{
      type: "quest/start_quest",
      category: "quest",
      label: "Start Quest",
      description: "Starts a quest for a user and returns the first step.",
      inputs: [
        %{name: "user_id", type: "string", required: true},
        %{name: "quest_id", type: "string", required: true}
      ],
      outputs: [
        %{name: "user_quest_id", type: "string"},
        %{name: "success", type: "boolean"},
        %{name: "first_step", type: "map"}
      ],
      config_fields: []
    }
  end
end
