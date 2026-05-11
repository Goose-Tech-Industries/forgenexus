defmodule ForgeNexus.Plugins.Nodes.Collection.GetProgress do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox
  alias ForgeNexus.Collections

  @impl true
  def execute(_config, inputs, ctx) do
    Sandbox.check_db_limit!(ctx)

    user_id = Map.get(inputs, :user_id) || Map.get(inputs, "user_id")
    set_id = Map.get(inputs, :set_id) || Map.get(inputs, "set_id")

    case Collections.get_progress(user_id, set_id) do
      {:ok, %{collected: collected, total: total, items: items}} ->
        ctx = Sandbox.increment_db_ops(ctx)
        percentage = if total > 0, do: Float.round(collected / total * 100, 1), else: 0.0

        {:ok,
         %{
           collected: collected,
           total: total,
           percentage: percentage,
           items: items
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
      type: "collection/get_progress",
      category: "collection",
      label: "Get Progress",
      description: "Retrieves a user's collection progress for a set, including per-item collected flags.",
      inputs: [
        %{name: "user_id", type: "string", required: true},
        %{name: "set_id", type: "string", required: true}
      ],
      outputs: [
        %{name: "collected", type: "number"},
        %{name: "total", type: "number"},
        %{name: "percentage", type: "number"},
        %{name: "items", type: "list"}
      ],
      config_fields: []
    }
  end
end
