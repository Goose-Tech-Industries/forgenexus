defmodule ForgeNexus.Plugins.Nodes.Quest.AdvanceQuest do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox

  @impl true
  def execute(_config, inputs, ctx) do
    Sandbox.check_db_limit!(ctx)

    user_quest_id = Map.get(inputs, :user_quest_id) || Map.get(inputs, "user_quest_id")

    case ForgeNexus.Quests.advance_quest(user_quest_id) do
      {:ok, updated_user_quest} ->
        ctx = Sandbox.increment_db_ops(ctx)

        {:ok,
         %{
           success: true,
           user_quest_id: updated_user_quest.id,
           status: updated_user_quest.status,
           current_step: updated_user_quest.current_step
         }, ctx}

      {:error, reason} ->
        ctx = Sandbox.increment_db_ops(ctx)
        {:error, "Failed to advance quest: #{inspect(reason)}", ctx}
    end
  end

  @impl true
  def validate_config(_config), do: :ok

  @impl true
  def schema do
    %{
      type: "quest/advance_quest",
      category: "quest",
      label: "Advance Quest",
      description: "Advances a user's quest to the next step or marks it as finished.",
      inputs: [
        %{name: "user_quest_id", type: "string", required: true}
      ],
      outputs: [
        %{name: "success", type: "boolean"},
        %{name: "new_step", type: "number"},
        %{name: "is_finished", type: "boolean"}
      ],
      config_fields: []
    }
  end
end
