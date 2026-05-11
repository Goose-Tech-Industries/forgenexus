defmodule ForgeNexus.Plugins.Nodes.Achievement.CheckAchievement do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox

  @impl true
  def execute(_config, inputs, ctx) do
    Sandbox.check_db_limit!(ctx)

    user_id = Map.get(inputs, :user_id) || Map.get(inputs, "user_id")
    achievement_id = Map.get(inputs, :achievement_id) || Map.get(inputs, "achievement_id")

    case ForgeNexus.Achievements.check_progress(user_id, achievement_id) do
      {:ok, progress_data} ->
        ctx = Sandbox.increment_db_ops(ctx)

        output = %{
          progress: progress_data.progress,
          target: progress_data.target,
          percentage: progress_data.percentage
        }

        if progress_data.earned do
          {:branch, "earned", output, ctx}
        else
          {:branch, "not_earned", output, ctx}
        end

      {:error, reason} ->
        ctx = Sandbox.increment_db_ops(ctx)
        {:error, "Failed to check achievement: #{inspect(reason)}", ctx}
    end
  end

  @impl true
  def validate_config(_config), do: :ok

  @impl true
  def schema do
    %{
      type: "achievement/check_achievement",
      category: "achievement",
      label: "Check Achievement",
      description: "Checks a user's progress toward an achievement and branches on earned/not earned.",
      inputs: [
        %{name: "user_id", type: "string", required: true},
        %{name: "achievement_id", type: "string", required: true}
      ],
      outputs: [
        %{name: "earned", type: "map"},
        %{name: "not_earned", type: "map"}
      ],
      config_fields: []
    }
  end
end
