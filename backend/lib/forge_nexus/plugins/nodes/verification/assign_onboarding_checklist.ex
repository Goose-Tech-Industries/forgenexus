defmodule ForgeNexus.Plugins.Nodes.Verification.AssignOnboardingChecklist do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox

  @impl true
  def execute(config, inputs, ctx) do
    Sandbox.check_db_limit!(ctx)
    user_id = Map.get(inputs, :user_id) || Map.get(inputs, "user_id")
    tasks = Map.get(config, "tasks", [])

    tasks =
      cond do
        is_list(tasks) ->
          tasks

        is_binary(tasks) ->
          case Jason.decode(tasks) do
            {:ok, parsed} when is_list(parsed) -> parsed
            _ -> []
          end

        true ->
          []
      end

    case ForgeNexus.Verification.create_onboarding_checklist(user_id, tasks) do
      {:ok, checklist} ->
        ctx = Sandbox.increment_db_ops(ctx)
        {:ok, %{checklist_id: checklist.id, success: true}, ctx}

      {:error, err} ->
        ctx = Sandbox.increment_db_ops(ctx)
        {:error, "Failed to assign checklist: #{inspect(err)}", ctx}
    end
  end

  @impl true
  def validate_config(config) do
    case Map.get(config, "tasks") do
      nil ->
        {:error, ["tasks is required"]}

      tasks when is_list(tasks) and length(tasks) > 0 ->
        :ok

      tasks when is_binary(tasks) ->
        case Jason.decode(tasks) do
          {:ok, parsed} when is_list(parsed) and length(parsed) > 0 -> :ok
          _ -> {:error, ["tasks must be a valid JSON list of {key, label} objects"]}
        end

      _ ->
        {:error, ["tasks must be a JSON list of {key, label} objects"]}
    end
  end

  @impl true
  def schema do
    %{
      type: "verification/assign_onboarding_checklist",
      category: "verification",
      label: "Assign Onboarding Checklist",
      description: "Assigns an onboarding checklist of tasks to a new user.",
      inputs: [%{name: "user_id", type: "string", required: true}],
      outputs: [
        %{name: "checklist_id", type: "string"},
        %{name: "success", type: "boolean"}
      ],
      config_fields: [
        %{
          name: "tasks",
          type: "json",
          default: [],
          description: "JSON list of {key, label} task objects"
        }
      ]
    }
  end
end
