defmodule ForgeNexus.Plugins.Nodes.Gambling.DiceRoll do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  @impl true
  def execute(config, _inputs, ctx) do
    notation = Map.get(config, "notation", "1d6")

    case parse_dice(notation) do
      {:ok, count, sides} ->
        rolls = Enum.map(1..count, fn _ -> :rand.uniform(sides) end)
        total = Enum.sum(rolls)
        {:ok, %{total: total, rolls: rolls, notation: notation}, ctx}

      :error ->
        {:error, "Invalid dice notation: #{notation}. Use NdS format (e.g. 2d6)", ctx}
    end
  end

  defp parse_dice(notation) when is_binary(notation) do
    case Regex.run(~r/^(\d+)d(\d+)$/i, notation) do
      [_, count_str, sides_str] ->
        count = String.to_integer(count_str)
        sides = String.to_integer(sides_str)

        if count > 0 and count <= 100 and sides > 0 and sides <= 1000 do
          {:ok, count, sides}
        else
          :error
        end

      _ ->
        :error
    end
  end

  defp parse_dice(_), do: :error

  @impl true
  def validate_config(config) do
    case Map.get(config, "notation", "1d6") do
      notation when is_binary(notation) ->
        if Regex.match?(~r/^\d+d\d+$/i, notation), do: :ok, else: {:error, ["notation must be in NdS format (e.g. 2d6)"]}

      _ ->
        {:error, ["notation must be a string in NdS format"]}
    end
  end

  @impl true
  def schema do
    %{
      type: "gambling/dice_roll",
      category: "gambling",
      label: "Dice Roll",
      description: "Rolls dice using NdS notation (e.g. 2d6 for two six-sided dice).",
      inputs: [],
      outputs: [
        %{name: "total", type: "number"},
        %{name: "rolls", type: "list"},
        %{name: "notation", type: "string"}
      ],
      config_fields: [
        %{name: "notation", type: "string", default: "1d6", description: "Dice notation in NdS format"}
      ]
    }
  end
end
