defmodule ForgeNexus.Plugins.Nodes.Economy.CurrencyExchange do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox
  alias ForgeNexus.Economy

  @impl true
  def execute(config, inputs, ctx) do
    Sandbox.check_db_limit!(ctx)

    user_id = Map.get(inputs, :user_id) || Map.get(inputs, "user_id")
    amount = Map.get(inputs, :amount) || Map.get(inputs, "amount") || 0
    from_currency = Map.get(config, "from_currency")
    to_currency = Map.get(config, "to_currency")
    rate = Map.get(config, "rate", 1.0) |> to_number()

    amount = to_number(amount)
    converted_amount = Float.round(amount * rate, 2)

    from_cur = Economy.get_currency_by_slug(from_currency)
    to_cur = Economy.get_currency_by_slug(to_currency)

    cond do
      is_nil(from_cur) ->
        {:error, "Source currency '#{from_currency}' not found", ctx}

      is_nil(to_cur) ->
        {:error, "Target currency '#{to_currency}' not found", ctx}

      true ->
        case Economy.deduct_points(user_id, from_cur.id, trunc(amount)) do
          {:ok, _} ->
            case Economy.award_points(user_id, to_cur.id, trunc(converted_amount)) do
              {:ok, _} ->
                ctx = Sandbox.increment_db_ops(ctx)
                {:ok, %{converted_amount: converted_amount, success: true}, ctx}

              {:error, reason} ->
                ctx = Sandbox.increment_db_ops(ctx)
                {:error, reason, ctx}
            end

          {:error, :insufficient_balance} ->
            ctx = Sandbox.increment_db_ops(ctx)
            {:error, "Insufficient balance for exchange", ctx}

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
        if Map.has_key?(config, "from_currency"), do: e, else: ["from_currency is required" | e]
      end)
      |> then(fn e ->
        if Map.has_key?(config, "to_currency"), do: e, else: ["to_currency is required" | e]
      end)
      |> then(fn e ->
        case Map.get(config, "rate") do
          nil -> e
          val when is_number(val) and val > 0 -> e
          _ -> ["rate must be a positive number" | e]
        end
      end)

    if errors == [], do: :ok, else: {:error, errors}
  end

  @impl true
  def schema do
    %{
      type: "economy/currency_exchange",
      category: "economy",
      label: "Currency Exchange",
      description: "Converts currency from one type to another at a given rate.",
      inputs: [
        %{name: "user_id", type: "string", required: true},
        %{name: "amount", type: "number", required: true}
      ],
      outputs: [
        %{name: "converted_amount", type: "number"},
        %{name: "success", type: "boolean"}
      ],
      config_fields: [
        %{
          name: "from_currency",
          type: "string",
          default: "",
          description: "Source currency slug"
        },
        %{name: "to_currency", type: "string", default: "", description: "Target currency slug"},
        %{name: "rate", type: "number", default: 1.0, description: "Exchange rate (from -> to)"}
      ]
    }
  end
end
