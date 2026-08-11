defmodule ForgeNexus.Plugins.Nodes.Poll.UpdateSuggestionStatus do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox

  @impl true
  def execute(config, inputs, ctx) do
    Sandbox.check_db_limit!(ctx)
    suggestion_id = Map.get(inputs, :suggestion_id) || Map.get(inputs, "suggestion_id")
    status = Map.get(config, "status", "open")

    case ForgeNexus.Predictions.update_suggestion_status(suggestion_id, status) do
      {:ok, _} ->
        ctx = Sandbox.increment_db_ops(ctx)
        {:ok, %{success: true}, ctx}

      {:error, err} ->
        ctx = Sandbox.increment_db_ops(ctx)
        {:error, "Failed to update suggestion: #{inspect(err)}", ctx}
    end
  end

  @impl true
  def validate_config(config) do
    if Map.get(config, "status", "open") in ~w(open planned in_progress done declined),
      do: :ok,
      else: {:error, ["status must be open, planned, in_progress, done, or declined"]}
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
