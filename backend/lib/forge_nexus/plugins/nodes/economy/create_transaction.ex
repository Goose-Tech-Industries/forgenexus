defmodule ForgeNexus.Plugins.Nodes.Economy.CreateTransaction do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox
  alias ForgeNexus.Economy

  @impl true
  def execute(config, inputs, ctx) do
    Sandbox.check_db_limit!(ctx)

    from_user_id = Map.get(inputs, :from_user_id) || Map.get(inputs, "from_user_id")
    to_user_id = Map.get(inputs, :to_user_id) || Map.get(inputs, "to_user_id")
    amount = Map.get(inputs, :amount) || Map.get(inputs, "amount") || 0
    transaction_type = Map.get(inputs, :transaction_type) || Map.get(inputs, "transaction_type")
    description = Map.get(inputs, :description) || Map.get(inputs, "description") || ""
    currency_slug = Map.get(config, "currency_slug", "points")

    amount = to_number(amount)

    currency = Economy.get_currency_by_slug(currency_slug)

    if is_nil(currency) do
      {:error, "Currency '#{currency_slug}' not found", ctx}
    else
      user_id = from_user_id || to_user_id

      case Economy.create_transaction(%{
             user_id: user_id,
             currency_id: currency.id,
             amount: trunc(amount),
             balance_after: 0,
             type: transaction_type,
             reason: description
           }) do
        {:ok, transaction} ->
          ctx = Sandbox.increment_db_ops(ctx)
          {:ok, %{transaction_id: transaction.id, success: true}, ctx}

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
      type: "economy/create_transaction",
      category: "economy",
      label: "Create Transaction",
      description: "Records a transaction between users or system accounts.",
      inputs: [
        %{name: "from_user_id", type: "string", required: false},
        %{name: "to_user_id", type: "string", required: false},
        %{name: "amount", type: "number", required: true},
        %{name: "transaction_type", type: "string", required: true},
        %{name: "description", type: "string", required: false}
      ],
      outputs: [
        %{name: "transaction_id", type: "string"},
        %{name: "success", type: "boolean"}
      ],
      config_fields: [
        %{
          name: "currency_slug",
          type: "string",
          default: "points",
          description: "Currency identifier slug"
        }
      ]
    }
  end
end
