defmodule ForgeNexus.Plugins.Nodes.Economy.TransferPoints do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox
  alias ForgeNexus.Economy

  @impl true
  def execute(config, inputs, ctx) do
    Sandbox.check_db_limit!(ctx)

    from_user_id = Map.get(inputs, :from_user_id) || Map.get(inputs, "from_user_id")
    to_user_id = Map.get(inputs, :to_user_id) || Map.get(inputs, "to_user_id")
    amount = Map.get(inputs, :amount) || Map.get(inputs, "amount") || 0
    currency_slug = Map.get(config, "currency_slug", "points")

    amount = to_number(amount)

    currency = Economy.get_currency_by_slug(currency_slug)

    if is_nil(currency) do
      {:error, "Currency '#{currency_slug}' not found", ctx}
    else
      case Economy.transfer_points(from_user_id, to_user_id, currency.id, trunc(amount)) do
        {:ok, :ok} ->
          ctx = Sandbox.increment_db_ops(ctx)
          {:ok, %{success: true}, ctx}

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
      type: "economy/transfer_points",
      category: "economy",
      label: "Transfer Points",
      description: "Transfers currency from one user to another.",
      inputs: [
        %{name: "from_user_id", type: "string", required: true},
        %{name: "to_user_id", type: "string", required: true},
        %{name: "amount", type: "number", required: true}
      ],
      outputs: [
        %{name: "success", type: "boolean"},
        %{name: "from_balance", type: "number"},
        %{name: "to_balance", type: "number"}
      ],
      config_fields: [
        %{name: "currency_slug", type: "string", default: "points", description: "Currency identifier slug"}
      ]
    }
  end
end
