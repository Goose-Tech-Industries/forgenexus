defmodule ForgeNexus.Plugins.Nodes.Poll.UpdateSuggestionStatus do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox

  @impl true
  def execute(config, inputs, ctx) do
    Sandbox.check_db_limit!(ctx)
    suggestion_id = Map.get(inputs, :suggestion_id) || Map.get(inputs, "suggestion_id")
    status = Map.get(config, "status", "open")

    mapped_status =
      case status do
        "open" -> "pending"
        "planned" -> "under_review"
        "in_progress" -> "under_review"
        "done" -> "completed"
        "declined" -> "rejected"
        s -> s
      end

    res =
      try do
        ForgeNexus.Predictions.update_suggestion_status(suggestion_id, mapped_status)
      rescue
        err -> {:error, Exception.message(err)}
      end

    case res do
      {:ok, _} ->
        ctx = Sandbox.increment_db_ops(ctx)
        {:ok, %{success: true}, ctx}

      {:error, err} ->
        ctx = Sandbox.increment_db_ops(ctx)
        {:error, "Failed to update suggestion: #{inspect(err)}", ctx}
    end
  end

  @valid_statuses ~w(open planned in_progress done declined pending under_review accepted approved rejected completed)

  @impl true
  def validate_config(config) do
    if Map.get(config, "status", "open") in @valid_statuses,
      do: :ok,
      else: {:error, ["status must be one of: #{Enum.join(@valid_statuses, ", ")}"]}
  end

  @impl true
  def schema do
    %{
      type: "poll/update_suggestion_status",
      category: "poll",
      label: "Update Suggestion Status",
      description:
        "Updates the status of a community suggestion with an optional admin response.",
      inputs: [%{name: "suggestion_id", type: "string", required: true}],
      outputs: [%{name: "success", type: "boolean"}],
      config_fields: [
        %{
          name: "status",
          type: "select",
          options: ~w(open planned in_progress done declined),
          default: "open",
          description: "New suggestion status"
        },
        %{
          name: "admin_response",
          type: "string",
          default: "",
          description: "Admin response or note about the status change"
        }
      ]
    }
  end
end
