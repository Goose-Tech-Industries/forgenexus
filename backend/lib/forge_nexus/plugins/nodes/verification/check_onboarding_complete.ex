defmodule ForgeNexus.Plugins.Nodes.Verification.CheckOnboardingComplete do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour
  import Ecto.Query

  alias ForgeNexus.Plugins.Engine.Sandbox

  @impl true
  def execute(_config, inputs, ctx) do
    Sandbox.check_db_limit!(ctx)
    user_id = Map.get(inputs, :user_id) || Map.get(inputs, "user_id")

    {completed_count, total_count} =
      case ForgeNexus.Repo.one(
             from c in ForgeNexus.Verification.OnboardingChecklist,
               where: c.user_id == ^user_id,
               order_by: [desc: c.inserted_at],
               limit: 1
           ) do
        nil ->
          {0, 0}

        checklist ->
          tasks = checklist.tasks || []
          total = length(tasks)
          done = Enum.count(tasks, fn t -> Map.get(t, "completed") == true or Map.get(t, :completed) == true end)
          {done, total}
      end

    ctx = Sandbox.increment_db_ops(ctx)
    outputs = %{completed_count: completed_count, total_count: total_count}

    if total_count > 0 and completed_count >= total_count do
      {:branch, "complete", outputs, ctx}
    else
      {:branch, "incomplete", outputs, ctx}
    end
  end

  @impl true
  def validate_config(_config), do: :ok

  @impl true
  def schema do
    %{
      type: "verification/check_onboarding_complete",
      category: "verification",
      label: "Check Onboarding Complete",
      description: "Branches based on whether a user has completed all onboarding tasks.",
      inputs: [%{name: "user_id", type: "string", required: true}],
      outputs: [
        %{name: "complete", type: "branch", fields: [%{name: "completed_count", type: "number"}, %{name: "total_count", type: "number"}]},
        %{name: "incomplete", type: "branch", fields: [%{name: "completed_count", type: "number"}, %{name: "total_count", type: "number"}]}
      ],
      config_fields: []
    }
  end
end
