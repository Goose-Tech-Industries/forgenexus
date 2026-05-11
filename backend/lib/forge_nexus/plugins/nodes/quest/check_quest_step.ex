defmodule ForgeNexus.Plugins.Nodes.Quest.CheckQuestStep do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox

  @impl true
  def execute(_config, inputs, ctx) do
    Sandbox.check_db_limit!(ctx)

    user_quest_id = Map.get(inputs, :user_quest_id) || Map.get(inputs, "user_quest_id")
    progress_value = Map.get(inputs, :progress_value) || Map.get(inputs, "progress_value") || 0

    progress_value =
      cond do
        is_number(progress_value) -> progress_value
        is_binary(progress_value) ->
          case Float.parse(progress_value) do
            {n, _} -> n
            :error -> 0
          end
        true -> 0
      end

    case ForgeNexus.Quests.check_step_progress(user_quest_id, %{progress: progress_value}) do
      {:ok, status} ->
        ctx = Sandbox.increment_db_ops(ctx)

        case status do
          :all_steps_complete ->
            {:branch, "complete", %{status: :all_steps_complete}, ctx}

          :step_complete ->
            {:branch, "complete", %{status: :step_complete}, ctx}

          :in_progress ->
            {:branch, "incomplete", %{status: :in_progress}, ctx}
        end

      {:error, reason} ->
        ctx = Sandbox.increment_db_ops(ctx)
        {:error, "Failed to check quest step: #{inspect(reason)}", ctx}
    end
  end

  @impl true
  def validate_config(_config), do: :ok

  @impl true
  def schema do
    %{
      type: "quest/check_quest_step",
      category: "quest",
      label: "Check Quest Step",
      description: "Checks progress on a quest step and branches on complete/incomplete.",
      inputs: [
        %{name: "user_quest_id", type: "string", required: true},
        %{name: "progress_value", type: "number", required: true}
      ],
      outputs: [
        %{name: "complete", type: "map"},
        %{name: "incomplete", type: "map"}
      ],
      config_fields: []
    }
  end
end
