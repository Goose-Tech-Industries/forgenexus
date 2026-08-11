defmodule ForgeNexus.Plugins.Nodes.Collection.AddToSet do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox
  alias ForgeNexus.Collections

  @impl true
  def execute(_config, inputs, ctx) do
    Sandbox.check_db_limit!(ctx)

    user_id = Map.get(inputs, :user_id) || Map.get(inputs, "user_id")

    collection_item_id =
      Map.get(inputs, :collection_item_id) || Map.get(inputs, "collection_item_id")

    case Collections.add_to_set(user_id, collection_item_id) do
      {:ok, %{was_new: was_new, progress_count: progress_count, total_count: total_count}} ->
        ctx = Sandbox.increment_db_ops(ctx)

        {:ok,
         %{
           success: true,
           was_new: was_new,
           progress_count: progress_count,
           total_count: total_count
         }, ctx}

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
      type: "collection/add_to_set",
      category: "collection",
      label: "Add to Set",
      description: "Adds a collection item to a user's collection progress.",
      inputs: [
        %{name: "user_id", type: "string", required: true},
        %{name: "collection_item_id", type: "string", required: true}
      ],
      outputs: [
        %{name: "success", type: "boolean"},
        %{name: "was_new", type: "boolean"},
        %{name: "progress_count", type: "number"},
        %{name: "total_count", type: "number"}
      ],
      config_fields: []
    }
  end
end
