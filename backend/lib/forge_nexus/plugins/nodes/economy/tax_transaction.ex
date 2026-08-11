defmodule ForgeNexus.Plugins.Nodes.Economy.TaxTransaction do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox
  alias ForgeNexus.Economy

  @impl true
  def execute(config, inputs, ctx) do
    Sandbox.check_db_limit!(ctx)

    user_id = Map.get(inputs, :user_id) || Map.get(inputs, "user_id")
    amount = Map.get(inputs, :amount) || Map.get(inputs, "amount") || 0
    currency_slug = Map.get(config, "currency_slug", "points")
    tax_rate_percent = Map.get(config, "tax_rate_percent", 5.0) |> to_number()

    amount = to_number(amount)
    tax_amount = Float.round(amount * tax_rate_percent / 100, 2)
    net_amount = amount - tax_amount

    currency = Economy.get_currency_by_slug(currency_slug)

    if is_nil(currency) do
      {:error, "Currency '#{currency_slug}' not found", ctx}
    else
      case Economy.deduct_points(user_id, currency.id, trunc(tax_amount)) do
        {:ok, _new_balance} ->
          ctx = Sandbox.increment_db_ops(ctx)
          {:ok, %{net_amount: net_amount, tax_amount: tax_amount, success: true}, ctx}

        {:error, :insufficient_balance} ->
          ctx = Sandbox.increment_db_ops(ctx)
          {:error, "Insufficient balance for tax", ctx}

        {:error, reason} ->
          ctx = Sandbox.increment_db_ops(ctx)
          {:error, reason, ctx}
      end
    end
  end

  defp to_number(val) when is_number(val), do: val / 1

  defp to_number(val) when is_binary(val) do
    case Float.parse(val) do
      {num, _} -> num
      :error -> 0.0
    end
  end

  defp to_number(_), do: 0.0

  @impl true
  def validate_config(config) do
    errors =
      []
      |> then(fn e ->
        case Map.get(config, "tax_rate_percent") do
          nil -> e
          val when is_number(val) and val >= 0 and val <= 100 -> e
          _ -> ["tax_rate_percent must be a number between 0 and 100" | e]
        end
      end)

    if errors == [], do: :ok, else: {:error, errors}
  end

  @impl true
  def schema do
    %{
      type: "economy/tax_transaction",
      category: "economy",
      label: "Tax Transaction",
      description: "Applies a tax to a transaction amount, deducting the tax from the user.",
      inputs: [
        %{name: "user_id", type: "string", required: true},
        %{name: "amount", type: "number", required: true}
      ],
      outputs: [
        %{name: "net_amount", type: "number"},
        %{name: "tax_amount", type: "number"},
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
          name: "tax_rate_percent",
          type: "number",
          default: 5.0,
          description: "Tax rate as a percentage"
        }
      ]
    }
  end
end
