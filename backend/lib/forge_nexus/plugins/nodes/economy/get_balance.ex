defmodule ForgeNexus.Plugins.Nodes.Economy.GetBalance do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox
  alias ForgeNexus.Economy

  @impl true
  def execute(config, inputs, ctx) do
    Sandbox.check_db_limit!(ctx)

    user_id = Map.get(inputs, :user_id) || Map.get(inputs, "user_id")
    currency_slug = Map.get(config, "currency_slug", "points")

    currency = Economy.get_currency_by_slug(currency_slug)

    if is_nil(currency) do
      {:error, "Currency '#{currency_slug}' not found", ctx}
    else
      balance = Economy.get_balance(user_id, currency.id)
      ctx = Sandbox.increment_db_ops(ctx)
      {:ok, %{balance: balance, currency_name: currency.name}, ctx}
    end
  end

  @impl true
  def validate_config(_config), do: :ok

  @impl true
  def schema do
    %{
      type: "economy/get_balance",
      category: "economy",
      label: "Get Balance",
      description: "Retrieves a user's balance for a given currency.",
      inputs: [
        %{name: "user_id", type: "string", required: true}
      ],
      outputs: [
        %{name: "balance", type: "number"},
        %{name: "currency_name", type: "string"}
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
