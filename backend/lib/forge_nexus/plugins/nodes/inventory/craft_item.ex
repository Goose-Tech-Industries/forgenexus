defmodule ForgeNexus.Plugins.Nodes.Inventory.CraftItem do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox
  alias ForgeNexus.Inventory

  @impl true
  def execute(_config, inputs, ctx) do
    Sandbox.check_db_limit!(ctx)

    user_id = Map.get(inputs, :user_id) || Map.get(inputs, "user_id")
    recipe_id = Map.get(inputs, :recipe_id) || Map.get(inputs, "recipe_id")

    case Inventory.craft_item(user_id, recipe_id) do
      {:ok, {:success, item}} ->
        ctx = Sandbox.increment_db_ops(ctx)
        {:ok, %{success: true, crafted: true, result_item: item}, ctx}

      {:ok, :failed} ->
        ctx = Sandbox.increment_db_ops(ctx)
        {:ok, %{success: true, crafted: false, result_item: nil}, ctx}

      {:error, reason} ->
        ctx = Sandbox.increment_db_ops(ctx)
        {:error, reason, ctx}
    end
  end

  @impl true
  def validate_config(_config), do: :ok

  @impl true
  def schema do
    %{
      type: "inventory/craft_item",
      category: "inventory",
      label: "Craft Item",
      description: "Attempts to craft an item using a recipe. Consumes ingredients and may fail based on success rate.",
      inputs: [
        %{name: "user_id", type: "string", required: true},
        %{name: "recipe_id", type: "string", required: true}
      ],
      outputs: [
        %{name: "success", type: "boolean"},
        %{name: "result_item", type: "map"},
        %{name: "was_successful", type: "boolean"}
      ],
      config_fields: []
    }
  end
end
