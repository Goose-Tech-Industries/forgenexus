defmodule ForgeNexus.Plugins.Nodes.Gambling.RouletteSpin do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  @red_numbers [1, 3, 5, 7, 9, 12, 14, 16, 18, 19, 21, 23, 25, 27, 30, 32, 34, 36]

  @impl true
  def execute(_config, _inputs, ctx) do
    number = :rand.uniform(37) - 1

    color =
      cond do
        number == 0 -> "green"
        number in @red_numbers -> "red"
        true -> "black"
      end

    is_even = number > 0 and rem(number, 2) == 0

    range =
      cond do
        number == 0 -> "0"
        number <= 18 -> "1-18"
        true -> "19-36"
      end

    {:ok, %{number: number, color: color, is_even: is_even, range: range}, ctx}
  end

  @impl true
  def validate_config(_config), do: :ok

  @impl true
  def schema do
    %{
      type: "gambling/roulette_spin",
      category: "gambling",
      label: "Roulette Spin",
      description: "Spins a roulette wheel (0-36) with color and range results.",
      inputs: [],
      outputs: [
        %{name: "number", type: "number"},
        %{name: "color", type: "string"},
        %{name: "is_even", type: "boolean"},
        %{name: "range", type: "string"}
      ],
      config_fields: []
    }
  end
end
