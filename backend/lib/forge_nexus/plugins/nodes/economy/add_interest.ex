defmodule ForgeNexus.Plugins.Nodes.Economy.AddInterest do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox
  alias ForgeNexus.Economy

  @impl true
  def execute(config, _inputs, ctx) do
    Sandbox.check_db_limit!(ctx)

    currency_slug = Map.get(config, "currency_slug", "points")
    rate_percent = Map.get(config, "rate_percent", 1.0) |> to_number()

    currency = Economy.get_currency_by_slug(currency_slug)

    if is_nil(currency) do
      {:error, "Currency '#{currency_slug}' not found", ctx}
    else
      case Economy.apply_interest(currency.id, rate_percent) do
        {:ok, count} ->
          ctx = Sandbox.increment_db_ops(ctx)
          {:ok, %{accounts_updated: count, total_interest: 0}, ctx}

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
      :error -> 0.0
    end
  end

  defp to_number(_), do: 0.0

  @impl true
  def validate_config(config) do
    errors =
      []
      |> then(fn e ->
        case Map.get(config, "rate_percent") do
          nil -> e
          val when is_number(val) and val >= 0 -> e
          _ -> ["rate_percent must be a non-negative number" | e]
        end
      end)

    if errors == [], do: :ok, else: {:error, errors}
  end

  @impl true
  def schema do
    %{
      type: "economy/add_interest",
      category: "economy",
      label: "Add Interest",
      description: "Applies interest to all balances of a given currency.",
      inputs: [],
      outputs: [
        %{name: "accounts_updated", type: "number"},
        %{name: "total_interest", type: "number"}
      ],
      config_fields: [
        %{name: "currency_slug", type: "string", default: "points", description: "Currency identifier slug"},
        %{name: "rate_percent", type: "number", default: 1.0, description: "Interest rate percentage to apply"}
      ]
    }
  end
end
