defmodule ForgeNexus.Plugins.Nodes.Logic.Compare do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  @impl true
  def execute(config, inputs, ctx) do
    operator = Map.get(config, "operator", "eq")
    a = Map.get(inputs, :a) || Map.get(inputs, "a")
    b = Map.get(inputs, :b) || Map.get(inputs, "b")

    result =
      case operator do
        "eq" -> a == b
        "neq" -> a != b
        "gt" -> to_number(a) > to_number(b)
        "gte" -> to_number(a) >= to_number(b)
        "lt" -> to_number(a) < to_number(b)
        "lte" -> to_number(a) <= to_number(b)
        _ -> false
      end

    {:ok, %{result: result}, ctx}
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
    if Map.get(config, "operator") in ~w(eq neq gt gte lt lte) do
      :ok
    else
      {:error, ["invalid operator"]}
    end
  end

  @impl true
  def schema do
    %{
      type: "logic/compare",
      category: "logic",
      label: "Compare",
      description: "Compares two values and outputs a boolean.",
      inputs: [
        %{name: "a", type: "any", required: true},
        %{name: "b", type: "any", required: true}
      ],
      outputs: [%{name: "result", type: "boolean"}],
      config_fields: [
        %{name: "operator", type: "select", options: ~w(eq neq gt gte lt lte), default: "eq", description: "Comparison operator"}
      ]
    }
  end
end
