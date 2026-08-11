defmodule ForgeNexus.Plugins.Nodes.Gambling.SlotMachine do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  @impl true
  def execute(config, _inputs, ctx) do
    symbols = parse_json(Map.get(config, "symbols", "[]"))
    paylines = parse_json(Map.get(config, "paylines", "[]"))

    if symbols == [] do
      {:error, "symbols list is empty", ctx}
    else
      total_weight =
        Enum.reduce(symbols, 0, fn s, acc ->
          acc + (Map.get(s, "weight") || Map.get(s, :weight) || 1)
        end)

      reels = Enum.map(1..3, fn _ -> pick_symbol(symbols, total_weight) end)

      {is_winner, multiplier} = check_paylines(reels, paylines)

      {:ok, %{reels: reels, is_winner: is_winner, multiplier: multiplier}, ctx}
    end
  end

  defp pick_symbol(symbols, total_weight) do
    roll = :rand.uniform() * total_weight

    Enum.reduce_while(symbols, 0, fn symbol, cumulative ->
      weight = Map.get(symbol, "weight") || Map.get(symbol, :weight) || 1
      cumulative = cumulative + weight

      if roll <= cumulative do
        {:halt, Map.get(symbol, "symbol") || Map.get(symbol, :symbol) || "?"}
      else
        {:cont, cumulative}
      end
    end)
    |> then(fn
      result when is_binary(result) -> result
      _ -> "?"
    end)
  end

  defp check_paylines(reels, paylines) do
    # Check if all three reels match (default jackpot)
    all_match = length(Enum.uniq(reels)) == 1

    matching_payline =
      Enum.find(paylines, fn payline ->
        pattern = Map.get(payline, "pattern") || Map.get(payline, :pattern) || []

        pattern =
          cond do
            is_list(pattern) -> pattern
            is_binary(pattern) -> String.split(pattern, ",")
            true -> []
          end

        pattern == reels
      end)

    cond do
      matching_payline != nil ->
        mult =
          Map.get(matching_payline, "multiplier") || Map.get(matching_payline, :multiplier) || 1

        {true, mult}

      all_match ->
        {true, 3}

      true ->
        {false, 0}
    end
  end

  defp parse_json(val) when is_list(val), do: val

  defp parse_json(val) when is_binary(val) do
    case Jason.decode(val) do
      {:ok, list} when is_list(list) -> list
      _ -> []
    end
  end

  defp parse_json(_), do: []

  @impl true
  def validate_config(config) do
    errors =
      []
      |> then(fn e ->
        symbols = parse_json(Map.get(config, "symbols", "[]"))
        if length(symbols) > 0, do: e, else: ["symbols must be a non-empty list" | e]
      end)

    if errors == [], do: :ok, else: {:error, errors}
  end

  @impl true
  def schema do
    %{
      type: "gambling/slot_machine",
      category: "gambling",
      label: "Slot Machine",
      description: "Spins a 3-reel slot machine with configurable symbols and paylines.",
      inputs: [],
      outputs: [
        %{name: "reels", type: "list"},
        %{name: "is_winner", type: "boolean"},
        %{name: "multiplier", type: "number"}
      ],
      config_fields: [
        %{
          name: "symbols",
          type: "json",
          default: "[]",
          description: "JSON array of {symbol, weight} objects"
        },
        %{
          name: "paylines",
          type: "json",
          default: "[]",
          description: "JSON array of {pattern, multiplier} objects"
        }
      ]
    }
  end
end
