defmodule ForgeNexus.Plugins.Nodes.Reputation.GetTradeRep do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox

  @impl true
  def execute(_config, inputs, ctx) do
    Sandbox.check_db_limit!(ctx)

    user_id = Map.get(inputs, :user_id) || Map.get(inputs, "user_id")

    case ForgeNexus.Reputation.get_trade_reputation(user_id) do
      {:ok, trade_rep} ->
        ctx = Sandbox.increment_db_ops(ctx)

        {:ok,
         %{
           trade_rep: trade_rep.score,
           successful_trades: trade_rep.successful_trades,
           total_trades: trade_rep.total_trades
         }, ctx}

      {:error, reason} ->
        ctx = Sandbox.increment_db_ops(ctx)
        {:error, "Failed to get trade reputation: #{inspect(reason)}", ctx}
    end
  end

  @impl true
  def validate_config(_config), do: :ok

  @impl true
  def schema do
    %{
      type: "reputation/get_trade_rep",
      category: "reputation",
      label: "Get Trade Rep",
      description: "Retrieves a user's trade-specific reputation and trade history stats.",
      inputs: [
        %{name: "user_id", type: "string", required: true}
      ],
      outputs: [
        %{name: "trade_rep", type: "number"},
        %{name: "successful_trades", type: "number"},
        %{name: "total_trades", type: "number"}
      ],
      config_fields: []
    }
  end
end
