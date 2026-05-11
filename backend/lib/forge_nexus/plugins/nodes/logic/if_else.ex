defmodule ForgeNexus.Plugins.Nodes.Logic.IfElse do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  @impl true
  def execute(config, inputs, ctx) do
    field = Map.get(config, "field")
    operator = Map.get(config, "operator")
    compare_value = Map.get(config, "value")

    actual_value = get_nested(inputs, field)

    result = compare(operator, actual_value, compare_value)

    port = if result, do: "true", else: "false"
    {:branch, port, inputs, ctx}
  end

  defp get_nested(map, field) when is_binary(field) do
    field
    |> String.split(".")
    |> Enum.reduce(map, fn key, acc ->
      case acc do
        %{} -> Map.get(acc, key) || Map.get(acc, String.to_existing_atom(key))
        _ -> nil
      end
    end)
  rescue
    ArgumentError -> nil
  end

  defp get_nested(map, _), do: map

  defp compare("eq", a, b), do: to_string(a) == to_string(b)
  defp compare("neq", a, b), do: to_string(a) != to_string(b)
  defp compare("gt", a, b), do: to_number(a) > to_number(b)
  defp compare("gte", a, b), do: to_number(a) >= to_number(b)
  defp compare("lt", a, b), do: to_number(a) < to_number(b)
  defp compare("lte", a, b), do: to_number(a) <= to_number(b)

  defp compare("contains", a, b) when is_binary(a) and is_binary(b) do
    String.contains?(a, b)
  end

  defp compare("contains", _a, _b), do: false

  defp compare("matches", a, b) when is_binary(a) and is_binary(b) do
    case Regex.compile(b) do
      {:ok, regex} -> Regex.match?(regex, a)
      _ -> false
    end
  end

  defp compare("matches", _a, _b), do: false
  defp compare(_, _a, _b), do: false

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
    errors =
      []
      |> then(fn e -> if Map.has_key?(config, "field"), do: e, else: ["field is required" | e] end)
      |> then(fn e ->
        if Map.get(config, "operator") in ~w(eq neq gt gte lt lte contains matches),
          do: e,
          else: ["invalid operator" | e]
      end)

    if errors == [], do: :ok, else: {:error, errors}
  end

  @impl true
  def schema do
    %{
      type: "logic/if_else",
      category: "logic",
      label: "If / Else",
      description: "Branches flow based on a condition.",
      inputs: [%{name: "input", type: "any", required: true}],
      outputs: [
        %{name: "true", type: "any"},
        %{name: "false", type: "any"}
      ],
      config_fields: [
        %{name: "field", type: "string", default: "", description: "Field path to check"},
        %{name: "operator", type: "select", options: ~w(eq neq gt gte lt lte contains matches), default: "eq", description: "Comparison operator"},
        %{name: "value", type: "string", default: "", description: "Value to compare against"}
      ]
    }
  end
end
