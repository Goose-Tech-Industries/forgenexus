defmodule ForgeNexus.Plugins.Nodes.Collection.GetMissing do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox
  alias ForgeNexus.Collections

  @impl true
  def execute(_config, inputs, ctx) do
    Sandbox.check_db_limit!(ctx)

    user_id = Map.get(inputs, :user_id) || Map.get(inputs, "user_id")
    set_id = Map.get(inputs, :set_id) || Map.get(inputs, "set_id")

    case Collections.get_missing(user_id, set_id) do
      {:ok, missing_items} ->
        ctx = Sandbox.increment_db_ops(ctx)
        {:ok, %{missing_items: missing_items, count: length(missing_items)}, ctx}

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
      type: "collection/get_missing",
      category: "collection",
      label: "Get Missing",
      description: "Returns the items a user is still missing from a collection set.",
      inputs: [
        %{name: "user_id", type: "string", required: true},
        %{name: "set_id", type: "string", required: true}
      ],
      outputs: [
        %{name: "missing_items", type: "list"},
        %{name: "count", type: "number"}
      ],
      config_fields: []
    }
  end
end
