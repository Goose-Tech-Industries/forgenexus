defmodule ForgeNexus.Plugins.Nodes.Gambling.CoinFlip do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  @impl true
  def execute(_config, _inputs, ctx) do
    is_heads = :rand.uniform(2) == 1
    result = if is_heads, do: "heads", else: "tails"

    {:ok, %{result: result, is_heads: is_heads}, ctx}
  end

  @impl true
  def validate_config(_config), do: :ok

  @impl true
  def schema do
    %{
      type: "gambling/coin_flip",
      category: "gambling",
      label: "Coin Flip",
      description: "Flips a coin, returning heads or tails.",
      inputs: [],
      outputs: [
        %{name: "result", type: "string"},
        %{name: "is_heads", type: "boolean"}
      ],
      config_fields: []
    }
  end
end
