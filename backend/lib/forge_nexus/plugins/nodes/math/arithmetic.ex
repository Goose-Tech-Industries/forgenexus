defmodule ForgeNexus.Plugins.Nodes.Math.Arithmetic do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  @impl true
  def execute(config, inputs, ctx) do
    operation = Map.get(config, "operation", "add")
    a = to_number(Map.get(inputs, :a) || Map.get(inputs, "a"))
    b = to_number(Map.get(inputs, :b) || Map.get(inputs, "b"))

    case operation do
      "add" -> {:ok, %{result: a + b}, ctx}
      "subtract" -> {:ok, %{result: a - b}, ctx}
      "multiply" -> {:ok, %{result: a * b}, ctx}
      "divide" when b == 0 -> {:error, "Division by zero", ctx}
      "divide" -> {:ok, %{result: a / b}, ctx}
      _ -> {:error, "Unknown operation: #{operation}", ctx}
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
    if Map.get(config, "operation") in ~w(add subtract multiply divide) do
      :ok
    else
      {:error, ["operation must be one of: add, subtract, multiply, divide"]}
    end
  end

  @impl true
  def schema do
    %{
      type: "math/arithmetic",
      category: "math",
      label: "Arithmetic",
      description: "Performs basic math operations on two numbers.",
      inputs: [
        %{name: "a", type: "number", required: true},
        %{name: "b", type: "number", required: true}
      ],
      outputs: [%{name: "result", type: "number"}],
      config_fields: [
        %{name: "operation", type: "select", options: ~w(add subtract multiply divide), default: "add", description: "Math operation"}
      ]
    }
  end
end
