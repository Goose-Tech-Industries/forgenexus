defmodule ForgeNexus.Plugins.Nodes.Economy.GetLeaderboard do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox
  alias ForgeNexus.Economy

  @impl true
  def execute(config, _inputs, ctx) do
    Sandbox.check_db_limit!(ctx)

    currency_slug = Map.get(config, "currency_slug", "points")
    limit = Map.get(config, "limit", 10) |> to_integer()

    currency = Economy.get_currency_by_slug(currency_slug)

    if is_nil(currency) do
      {:error, "Currency '#{currency_slug}' not found", ctx}
    else
      entries = Economy.get_leaderboard(currency.id, limit)
      ctx = Sandbox.increment_db_ops(ctx)
      {:ok, %{entries: entries}, ctx}
    end
  end

  defp to_integer(val) when is_integer(val), do: val
  defp to_integer(val) when is_float(val), do: trunc(val)

  defp to_integer(val) when is_binary(val) do
    case Integer.parse(val) do
      {n, _} -> n
      :error -> 10
    end
  end

  defp to_integer(_), do: 10

  @impl true
  def validate_config(_config), do: :ok

  @impl true
  def schema do
    %{
      type: "economy/get_leaderboard",
      category: "economy",
      label: "Get Leaderboard",
      description: "Retrieves top users ranked by currency balance.",
      inputs: [],
      outputs: [
        %{name: "entries", type: "list"}
      ],
      config_fields: [
        %{name: "currency_slug", type: "string", default: "points", description: "Currency identifier slug"},
        %{name: "limit", type: "number", default: 10, description: "Number of entries to return"}
      ]
    }
  end
end
