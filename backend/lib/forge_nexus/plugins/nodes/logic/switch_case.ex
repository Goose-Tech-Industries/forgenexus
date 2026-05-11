defmodule ForgeNexus.Plugins.Nodes.Logic.SwitchCase do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  @impl true
  def execute(config, inputs, ctx) do
    field = Map.get(config, "field")
    cases = Map.get(config, "cases", [])
    default_port = Map.get(config, "default_port", "default")

    actual_value = get_nested(inputs, field)

    matched =
      Enum.find(cases, fn c ->
        to_string(Map.get(c, "value")) == to_string(actual_value)
      end)

    port =
      case matched do
        nil -> default_port
        c -> Map.get(c, "port", default_port)
      end

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

  @impl true
  def validate_config(config) do
    errors =
      []
      |> then(fn e -> if Map.has_key?(config, "field"), do: e, else: ["field is required" | e] end)
      |> then(fn e -> if is_list(Map.get(config, "cases")), do: e, else: ["cases must be a list" | e] end)

    if errors == [], do: :ok, else: {:error, errors}
  end

  @impl true
  def schema do
    %{
      type: "logic/switch_case",
      category: "logic",
      label: "Switch / Case",
      description: "Routes flow to different branches based on a value.",
      inputs: [%{name: "input", type: "any", required: true}],
      outputs: [%{name: "matched_port", type: "any"}],
      config_fields: [
        %{name: "field", type: "string", default: "", description: "Field path to switch on"},
        %{name: "cases", type: "json", default: [], description: "List of {value, port} case objects"},
        %{name: "default_port", type: "string", default: "default", description: "Port for unmatched values"}
      ]
    }
  end
end
