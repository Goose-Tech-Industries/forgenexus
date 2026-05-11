defmodule ForgeNexus.Plugins.Nodes.Reputation.CheckReputation do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox

  @impl true
  def execute(config, inputs, ctx) do
    Sandbox.check_db_limit!(ctx)

    user_id = Map.get(inputs, :user_id) || Map.get(inputs, "user_id")
    threshold = Map.get(config, "threshold", 0)

    case ForgeNexus.Reputation.get_reputation(user_id) do
      {:ok, rep} ->
        ctx = Sandbox.increment_db_ops(ctx)
        reputation = rep.total

        if reputation >= threshold do
          {:branch, "above", %{reputation: reputation}, ctx}
        else
          {:branch, "below", %{reputation: reputation}, ctx}
        end

      {:error, reason} ->
        ctx = Sandbox.increment_db_ops(ctx)
        {:error, "Failed to check reputation: #{inspect(reason)}", ctx}
    end
  end

  @impl true
  def validate_config(config) do
    threshold = Map.get(config, "threshold")

    if is_nil(threshold) or is_number(threshold) do
      :ok
    else
      {:error, ["threshold must be a number"]}
    end
  end

  @impl true
  def schema do
    %{
      type: "reputation/check_reputation",
      category: "reputation",
      label: "Check Reputation",
      description: "Branches based on whether a user's reputation is above or below a threshold.",
      inputs: [
        %{name: "user_id", type: "string", required: true}
      ],
      outputs: [
        %{name: "above", type: "number"},
        %{name: "below", type: "number"}
      ],
      config_fields: [
        %{name: "threshold", type: "number", default: 0, description: "Reputation threshold to check against"}
      ]
    }
  end
end
