defmodule ForgeNexus.Plugins.Nodes.Logic.Loop do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  @impl true
  def execute(config, inputs, ctx) do
    source_field = Map.get(config, "source_field", "items")
    item_variable = Map.get(config, "item_variable", "item")

    items =
      Map.get(inputs, source_field) || Map.get(inputs, String.to_existing_atom(source_field))

    case items do
      list when is_list(list) ->
        # The executor handles loop body execution specially.
        # We return the list and metadata; the executor iterates.
        {:ok,
         %{
           items: list,
           count: length(list),
           _loop: true,
           _source_field: source_field,
           _item_variable: item_variable
         }, ctx}

      _ ->
        {:error, "Source field '#{source_field}' is not a list", ctx}
    end
  rescue
    ArgumentError ->
      {:error, "Source field '#{Map.get(config, "source_field", "items")}' not found", ctx}
  end

  @impl true
  def validate_config(config) do
    errors =
      []
      |> then(fn e ->
        if Map.has_key?(config, "source_field"), do: e, else: ["source_field is required" | e]
      end)

    if errors == [], do: :ok, else: {:error, errors}
  end

  @impl true
  def schema do
    %{
      type: "logic/loop",
      category: "logic",
      label: "Loop",
      description: "Iterates over a list, executing downstream nodes for each item.",
      inputs: [%{name: "items", type: "list", required: true}],
      outputs: [
        %{name: "item", type: "any"},
        %{name: "index", type: "number"},
        %{name: "count", type: "number"}
      ],
      config_fields: [
        %{
          name: "source_field",
          type: "string",
          default: "items",
          description: "Field containing the list to iterate"
        },
        %{
          name: "item_variable",
          type: "string",
          default: "item",
          description: "Variable name for the current item"
        }
      ]
    }
  end
end
