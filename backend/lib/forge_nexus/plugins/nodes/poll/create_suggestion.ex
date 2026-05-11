defmodule ForgeNexus.Plugins.Nodes.Poll.CreateSuggestion do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox

  @impl true
  def execute(config, inputs, ctx) do
    Sandbox.check_db_limit!(ctx)
    user_id = Map.get(inputs, :user_id) || Map.get(inputs, "user_id")
    title = Map.get(inputs, :title) || Map.get(inputs, "title")
    description = Map.get(inputs, :description) || Map.get(inputs, "description")
    _category = Map.get(config, "category", "")

    attrs = %{
      title: title,
      description: description,
      user_id: user_id,
      status: "pending"
    }

    case ForgeNexus.Predictions.create_suggestion(attrs) do
      {:ok, suggestion} ->
        ctx = Sandbox.increment_db_ops(ctx)
        {:ok, %{suggestion_id: suggestion.id, success: true}, ctx}

      {:error, err} ->
        ctx = Sandbox.increment_db_ops(ctx)
        {:error, "Failed to create suggestion: #{inspect(err)}", ctx}
    end
  end

  @impl true
  def validate_config(_config), do: :ok

  @impl true
  def schema do
    %{
      type: "poll/create_suggestion",
      category: "poll",
      label: "Create Suggestion",
      description: "Creates a community suggestion that can be voted on and tracked.",
      inputs: [
        %{name: "user_id", type: "string", required: true},
        %{name: "title", type: "string", required: true},
        %{name: "description", type: "string", required: true}
      ],
      outputs: [
        %{name: "suggestion_id", type: "string"},
        %{name: "success", type: "boolean"}
      ],
      config_fields: [
        %{name: "category", type: "string", default: "", description: "Suggestion category"}
      ]
    }
  end
end
