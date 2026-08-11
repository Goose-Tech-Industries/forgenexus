defmodule ForgeNexus.Plugins.Nodes.Poll.ResolvePrediction do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox

  @impl true
  def execute(_config, inputs, ctx) do
    Sandbox.check_db_limit!(ctx)
    prediction_id = Map.get(inputs, :prediction_id) || Map.get(inputs, "prediction_id")
    winning_option = Map.get(inputs, :winning_option) || Map.get(inputs, "winning_option")

    case ForgeNexus.Predictions.resolve_prediction(prediction_id, winning_option) do
      {:ok, %{total_payout: tp, winners_count: wc}} ->
        ctx = Sandbox.increment_db_ops(ctx)
        {:ok, %{total_payout: tp, winners_count: wc, success: true}, ctx}

      {:ok, _other} ->
        ctx = Sandbox.increment_db_ops(ctx)
        {:ok, %{total_payout: 0, winners_count: 0, success: true}, ctx}

      {:error, err} ->
        ctx = Sandbox.increment_db_ops(ctx)
        {:error, "Failed to resolve prediction: #{inspect(err)}", ctx}
    end
  end

  @impl true
  def validate_config(_config), do: :ok

  @impl true
  def schema do
    %{
      type: "poll/resolve_prediction",
      category: "poll",
      label: "Resolve Prediction",
      description:
        "Resolves a prediction market by selecting the winning option and distributing payouts.",
      inputs: [
        %{name: "prediction_id", type: "string", required: true},
        %{name: "winning_option", type: "string", required: true}
      ],
      outputs: [
        %{name: "total_payout", type: "number"},
        %{name: "winners_count", type: "number"},
        %{name: "success", type: "boolean"}
      ],
      config_fields: []
    }
  end
end
