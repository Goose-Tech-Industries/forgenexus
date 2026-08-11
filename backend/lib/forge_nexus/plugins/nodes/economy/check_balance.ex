defmodule ForgeNexus.Plugins.Nodes.Economy.CheckBalance do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox
  alias ForgeNexus.Economy

  @impl true
  def execute(config, inputs, ctx) do
    Sandbox.check_db_limit!(ctx)

    user_id = Map.get(inputs, :user_id) || Map.get(inputs, "user_id")
    currency_slug = Map.get(config, "currency_slug", "points")
    threshold = Map.get(config, "threshold", 0) |> to_number()

    currency = Economy.get_currency_by_slug(currency_slug)

    if is_nil(currency) do
      {:error, "Currency '#{currency_slug}' not found", ctx}
    else
      balance = Economy.get_balance(user_id, currency.id)
      ctx = Sandbox.increment_db_ops(ctx)
      port = if balance >= threshold, do: "sufficient", else: "insufficient"
      {:branch, port, %{balance: balance}, ctx}
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
    errors =
      []
      |> then(fn e ->
        case Map.get(config, "threshold") do
          nil -> e
          val when is_number(val) -> e
          _ -> ["threshold must be a number" | e]
        end
      end)

    if errors == [], do: :ok, else: {:error, errors}
  end

  @impl true
  def schema do
    %{
      type: "economy/check_balance",
      category: "economy",
      label: "Check Balance",
      description: "Branches based on whether a user's balance meets a threshold.",
      inputs: [
        %{name: "user_id", type: "string", required: true}
      ],
      outputs: [
        %{name: "sufficient", type: "number"},
        %{name: "insufficient", type: "number"}
      ],
      config_fields: [
        %{
          name: "currency_slug",
          type: "string",
          default: "points",
          description: "Currency identifier slug"
        },
        %{name: "threshold", type: "number", default: 0, description: "Minimum balance threshold"}
      ]
    }
  end
end
