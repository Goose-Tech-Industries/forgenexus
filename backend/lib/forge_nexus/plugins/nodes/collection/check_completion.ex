defmodule ForgeNexus.Plugins.Nodes.Collection.CheckCompletion do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox
  alias ForgeNexus.Collections

  @impl true
  def execute(_config, inputs, ctx) do
    Sandbox.check_db_limit!(ctx)

    user_id = Map.get(inputs, :user_id) || Map.get(inputs, "user_id")
    set_id = Map.get(inputs, :set_id) || Map.get(inputs, "set_id")

    case Collections.get_progress(user_id, set_id) do
      {:ok, %{collected: collected, total: total}} ->
        ctx = Sandbox.increment_db_ops(ctx)
        percentage = if total > 0, do: Float.round(collected / total * 100, 1), else: 0.0
        port = if collected >= total and total > 0, do: "complete", else: "incomplete"

        {:branch, port, %{collected: collected, total: total, percentage: percentage}, ctx}

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
      type: "collection/check_completion",
      category: "collection",
      label: "Check Completion",
      description: "Branches based on whether a user has completed a collection set.",
      inputs: [
        %{name: "user_id", type: "string", required: true},
        %{name: "set_id", type: "string", required: true}
      ],
      outputs: [
        %{name: "complete", type: "number"},
        %{name: "incomplete", type: "number"}
      ],
      config_fields: []
    }
  end
end
