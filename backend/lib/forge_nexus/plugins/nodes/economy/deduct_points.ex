defmodule ForgeNexus.Plugins.Nodes.Economy.DeductPoints do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox
  alias ForgeNexus.Economy

  @impl true
  def execute(config, inputs, ctx) do
    Sandbox.check_db_limit!(ctx)

    user_id = Map.get(inputs, :user_id) || Map.get(inputs, "user_id")
    amount = Map.get(inputs, :amount) || Map.get(inputs, "amount") || 0
    currency_slug = Map.get(config, "currency_slug", "points")
    _reason = Map.get(config, "reason", "deduction")

    amount = to_number(amount)

    currency = Economy.get_currency_by_slug(currency_slug)

    if is_nil(currency) do
      {:error, "Currency '#{currency_slug}' not found", ctx}
    else
      case Economy.deduct_points(user_id, currency.id, trunc(amount)) do
        {:ok, new_balance} ->
          ctx = Sandbox.increment_db_ops(ctx)
          {:ok, %{new_balance: new_balance, success: true}, ctx}

        {:error, :insufficient_balance} ->
          ctx = Sandbox.increment_db_ops(ctx)
          {:error, "Insufficient balance", ctx}

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
  def validate_config(_config), do: :ok

  @impl true
  def schema do
    %{
      type: "economy/deduct_points",
      category: "economy",
      label: "Deduct Points",
      description: "Deducts currency from a user's balance. Fails if insufficient funds.",
      inputs: [
        %{name: "user_id", type: "string", required: true},
        %{name: "amount", type: "number", required: true}
      ],
      outputs: [
        %{name: "new_balance", type: "number"},
        %{name: "success", type: "boolean"}
      ],
      config_fields: [
        %{
          name: "currency_slug",
          type: "string",
          default: "points",
          description: "Currency identifier slug"
        },
        %{name: "reason", type: "string", default: "", description: "Reason for the deduction"}
      ]
    }
  end
end
