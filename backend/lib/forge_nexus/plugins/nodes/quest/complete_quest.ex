defmodule ForgeNexus.Plugins.Nodes.Quest.CompleteQuest do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox

  @impl true
  def execute(_config, inputs, ctx) do
    Sandbox.check_db_limit!(ctx)

    user_quest_id = Map.get(inputs, :user_quest_id) || Map.get(inputs, "user_quest_id")

    case ForgeNexus.Quests.complete_quest(user_quest_id) do
      {:ok, rewards_list} ->
        ctx = Sandbox.increment_db_ops(ctx)

        {:ok,
         %{
           rewards: rewards_list,
           success: true
         }, ctx}

      {:error, reason} ->
        ctx = Sandbox.increment_db_ops(ctx)
        {:error, "Failed to complete quest: #{inspect(reason)}", ctx}
    end
  end

  @impl true
  def validate_config(_config), do: :ok

  @impl true
  def schema do
    %{
      type: "quest/complete_quest",
      category: "quest",
      label: "Complete Quest",
      description: "Completes a quest and distributes rewards to the user.",
      inputs: [
        %{name: "user_quest_id", type: "string", required: true}
      ],
      outputs: [
        %{name: "rewards", type: "map"},
        %{name: "success", type: "boolean"}
      ],
      config_fields: []
    }
  end
end
