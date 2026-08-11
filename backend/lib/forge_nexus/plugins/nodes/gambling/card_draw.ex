defmodule ForgeNexus.Plugins.Nodes.Gambling.CardDraw do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  @standard_suits ~w(hearts diamonds clubs spades)
  @standard_values ~w(A 2 3 4 5 6 7 8 9 10 J Q K)

  @impl true
  def execute(config, _inputs, ctx) do
    deck_type = Map.get(config, "deck_type", "standard")
    count = Map.get(config, "count", 1) |> to_integer()

    deck = build_deck(deck_type)
    count = min(count, length(deck))

    drawn = deck |> Enum.shuffle() |> Enum.take(count)
    remaining = length(deck) - count

    cards =
      Enum.map(drawn, fn card ->
        %{
          suit: Map.get(card, :suit),
          value: Map.get(card, :value),
          display: "#{Map.get(card, :value)} of #{Map.get(card, :suit)}"
        }
      end)

    {:ok, %{cards: cards, remaining: remaining}, ctx}
  end

  defp build_deck("standard") do
    for suit <- @standard_suits, value <- @standard_values do
      %{suit: suit, value: value}
    end
  end

  defp build_deck(_), do: build_deck("standard")

  defp to_integer(val) when is_integer(val), do: val
  defp to_integer(val) when is_float(val), do: trunc(val)

  defp to_integer(val) when is_binary(val) do
    case Integer.parse(val) do
      {n, _} -> n
      :error -> 1
    end
  end

  defp to_integer(_), do: 1

  @impl true
  def validate_config(_config), do: :ok

  @impl true
  def schema do
    %{
      type: "gambling/card_draw",
      category: "gambling",
      label: "Card Draw",
      description: "Draws cards from a deck.",
      inputs: [],
      outputs: [
        %{name: "cards", type: "list"},
        %{name: "remaining", type: "number"}
      ],
      config_fields: [
        %{
          name: "deck_type",
          type: "select",
          options: ~w(standard custom),
          default: "standard",
          description: "Type of deck to draw from"
        },
        %{name: "count", type: "number", default: 1, description: "Number of cards to draw"}
      ]
    }
  end
end
