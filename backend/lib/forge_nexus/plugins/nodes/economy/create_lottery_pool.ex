defmodule ForgeNexus.Plugins.Nodes.Economy.CreateLotteryPool do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox
  alias ForgeNexus.Economy

  @impl true
  def execute(config, inputs, ctx) do
    Sandbox.check_db_limit!(ctx)

    user_id = Map.get(inputs, :user_id) || Map.get(inputs, "user_id")
    amount = Map.get(inputs, :amount) || Map.get(inputs, "amount") || 0
    currency_slug = Map.get(config, "currency_slug", "points")
    pool_key = Map.get(config, "pool_key", "default_pool")

    amount = to_number(amount)

    currency = Economy.get_currency_by_slug(currency_slug)

    if is_nil(currency) do
      {:error, "Currency '#{currency_slug}' not found", ctx}
    else
      case Economy.deduct_points(user_id, currency.id, trunc(amount)) do
        {:ok, _new_balance} ->
          Economy.create_transaction(%{
            user_id: user_id,
            currency_id: currency.id,
            amount: trunc(amount),
            balance_after: 0,
            type: "deduct",
            reason: pool_key
          })

          ctx = Sandbox.increment_db_ops(ctx)
          {:ok, %{pool_total: trunc(amount), success: true}, ctx}

        {:error, :insufficient_balance} ->
          ctx = Sandbox.increment_db_ops(ctx)
          {:error, "Insufficient balance for lottery pool", ctx}

        {:error, reason} ->
          ctx = Sandbox.increment_db_ops(ctx)
          {:error, reason, ctx}
      end
    end
  end

  defp to_number(val) when is_number(val), do: val

  defp to_number(val) when is_binary(val) do
    case Float.parse(val) do
      {num, _} -> num
      :error -> 0
    end
  end

  defp to_number(_), do: 0

  @impl true
  def validate_config(config) do
    if Map.has_key?(config, "pool_key"), do: :ok, else: {:error, ["pool_key is required"]}
  end

  @impl true
  def schema do
    %{
      type: "economy/create_lottery_pool",
      category: "economy",
      label: "Create Lottery Pool",
      description: "Deducts currency from a user and adds it to a shared lottery pool.",
      inputs: [
        %{name: "user_id", type: "string", required: true},
        %{name: "amount", type: "number", required: true}
      ],
      outputs: [
        %{name: "pool_total", type: "number"},
        %{name: "success", type: "boolean"}
      ],
      config_fields: [
        %{
          name: "currency_slug",
          type: "string",
          default: "points",
          description: "Currency identifier slug"
        },
        %{
          name: "pool_key",
          type: "string",
          default: "",
          description: "Unique key identifying the lottery pool"
        }
      ]
    }
  end
end
