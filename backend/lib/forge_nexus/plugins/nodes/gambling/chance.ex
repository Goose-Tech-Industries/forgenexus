defmodule ForgeNexus.Plugins.Nodes.Gambling.Chance do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  @impl true
  def execute(config, _inputs, ctx) do
    probability = Map.get(config, "probability", 50) |> to_number()
    probability = max(0, min(100, probability))

    roll = :rand.uniform() * 100
    port = if roll <= probability, do: "success", else: "failure"

    {:branch, port, %{roll: Float.round(roll, 2)}, ctx}
  end

  defp to_number(val) when is_number(val), do: val

  defp to_number(val) when is_binary(val) do
    case Float.parse(val) do
      {num, _} -> num
      :error -> 50
    end
  end

  defp to_number(_), do: 50

  @impl true
  def validate_config(config) do
    case Map.get(config, "probability") do
      nil -> :ok
      val when is_number(val) and val >= 0 and val <= 100 -> :ok
      _ -> {:error, ["probability must be a number between 0 and 100"]}
    end
  end

  @impl true
  def schema do
    %{
      type: "gambling/chance",
      category: "gambling",
      label: "Chance",
      description: "Branches based on a probability roll (0-100%).",
      inputs: [],
      outputs: [
        %{name: "success", type: "number"},
        %{name: "failure", type: "number"}
      ],
      config_fields: [
        %{
          name: "probability",
          type: "number",
          default: 50,
          description: "Success probability (0-100)"
        }
      ]
    }
  end
end
