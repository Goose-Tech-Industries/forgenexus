defmodule ForgeNexus.Plugins.Nodes.Reputation.ScaleRepPower do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox

  @impl true
  def execute(_config, inputs, ctx) do
    Sandbox.check_db_limit!(ctx)

    user_id = Map.get(inputs, :user_id) || Map.get(inputs, "user_id")
    base_amount = Map.get(inputs, :base_amount) || Map.get(inputs, "base_amount") || 1

    base_amount =
      cond do
        is_number(base_amount) -> base_amount
        is_binary(base_amount) ->
          case Float.parse(base_amount) do
            {n, _} -> n
            :error -> 1
          end
        true -> 1
      end

    case ForgeNexus.Reputation.get_reputation(user_id) do
      {:ok, rep} ->
        ctx = Sandbox.increment_db_ops(ctx)
        reputation = rep.total

        # Multiplier scales with giver's reputation: 1.0 base + 0.1 per 100 rep, capped at 3.0
        multiplier = min(3.0, 1.0 + reputation / 1000.0)
        multiplier = max(0.1, multiplier)
        scaled = Float.round(base_amount * multiplier, 2)

        {:ok, %{scaled_amount: scaled, rep_multiplier: Float.round(multiplier, 2)}, ctx}

      {:error, reason} ->
        ctx = Sandbox.increment_db_ops(ctx)
        {:error, "Failed to scale rep power: #{inspect(reason)}", ctx}
    end
  end

  @impl true
  def validate_config(_config), do: :ok

  @impl true
  def schema do
    %{
      type: "reputation/scale_rep_power",
      category: "reputation",
      label: "Scale Rep Power",
      description: "Calculates a scaled amount based on the giver's own reputation level.",
      inputs: [
        %{name: "user_id", type: "string", required: true},
        %{name: "base_amount", type: "number", required: true}
      ],
      outputs: [
        %{name: "scaled_amount", type: "number"},
        %{name: "rep_multiplier", type: "number"}
      ],
      config_fields: []
    }
  end
end
