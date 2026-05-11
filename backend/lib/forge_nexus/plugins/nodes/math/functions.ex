defmodule ForgeNexus.Plugins.Nodes.Math.Functions do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  @impl true
  def execute(config, inputs, ctx) do
    function = Map.get(config, "function", "min")

    case function do
      "min" ->
        a = to_number(Map.get(inputs, :a) || Map.get(inputs, "a"))
        b = to_number(Map.get(inputs, :b) || Map.get(inputs, "b"))
        {:ok, %{result: min(a, b)}, ctx}

      "max" ->
        a = to_number(Map.get(inputs, :a) || Map.get(inputs, "a"))
        b = to_number(Map.get(inputs, :b) || Map.get(inputs, "b"))
        {:ok, %{result: max(a, b)}, ctx}

      "round" ->
        value = to_number(Map.get(inputs, :value) || Map.get(inputs, "value"))
        precision = to_number(Map.get(inputs, :precision) || Map.get(inputs, "precision") || 0)
        {:ok, %{result: Float.round(value / 1, trunc(precision))}, ctx}

      "random_number" ->
        min_val = to_number(Map.get(inputs, :min) || Map.get(inputs, "min") || 0)
        max_val = to_number(Map.get(inputs, :max) || Map.get(inputs, "max") || 100)

        result =
          if max_val > min_val do
            min_val + :rand.uniform() * (max_val - min_val)
          else
            min_val
          end

        {:ok, %{result: result}, ctx}

      "clamp" ->
        value = to_number(Map.get(inputs, :value) || Map.get(inputs, "value"))
        min_val = to_number(Map.get(inputs, :min) || Map.get(inputs, "min"))
        max_val = to_number(Map.get(inputs, :max) || Map.get(inputs, "max"))
        {:ok, %{result: value |> max(min_val) |> min(max_val)}, ctx}

      _ ->
        {:error, "Unknown function: #{function}", ctx}
    end
  end

  defp to_number(val) when is_number(val), do: val * 1.0

  defp to_number(val) when is_binary(val) do
    case Float.parse(val) do
      {num, _} -> num
      :error -> 0.0
    end
  end

  defp to_number(nil), do: 0.0
  defp to_number(_), do: 0.0

  @impl true
  def validate_config(config) do
    if Map.get(config, "function") in ~w(min max round random_number clamp) do
      :ok
    else
      {:error, ["function must be one of: min, max, round, random_number, clamp"]}
    end
  end

  @impl true
  def schema do
    %{
      type: "math/functions",
      category: "math",
      label: "Math Functions",
      description: "Common math functions: min, max, round, random_number, clamp.",
      inputs: [
        %{name: "value", type: "number", required: false},
        %{name: "a", type: "number", required: false},
        %{name: "b", type: "number", required: false},
        %{name: "min", type: "number", required: false},
        %{name: "max", type: "number", required: false},
        %{name: "precision", type: "number", required: false}
      ],
      outputs: [%{name: "result", type: "number"}],
      config_fields: [
        %{name: "function", type: "select", options: ~w(min max round random_number clamp), default: "min", description: "Math function to apply"}
      ]
    }
  end
end
