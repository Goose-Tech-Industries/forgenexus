defmodule ForgeNexus.Plugins.Nodes.Integration.ParseWebhook do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  require Logger

  @impl true
  def execute(config, inputs, ctx) do
    payload = Map.get(inputs, :payload) || Map.get(inputs, "payload", %{})
    mappings = Map.get(config, "mappings", %{})

    mappings =
      cond do
        is_map(mappings) -> mappings
        is_binary(mappings) ->
          case Jason.decode(mappings) do
            {:ok, parsed} when is_map(parsed) -> parsed
            _ -> %{}
          end
        true -> %{}
      end

    # Extract fields from payload using simple dot-separated JSON path notation
    extracted =
      Enum.reduce(mappings, %{}, fn {output_field, json_path}, acc ->
        value = get_by_path(payload, json_path)
        Map.put(acc, output_field, value)
      end)

    Logger.info("[PluginFlow] integration/parse_webhook: extracted #{map_size(extracted)} fields")

    {:ok, %{extracted: extracted}, ctx}
  end

  defp get_by_path(data, path) when is_binary(path) do
    path
    |> String.split(".")
    |> Enum.reduce(data, fn key, acc ->
      case acc do
        %{} -> Map.get(acc, key) || Map.get(acc, String.to_existing_atom(key), nil)
        _ -> nil
      end
    end)
  rescue
    ArgumentError -> nil
  end

  defp get_by_path(_, _), do: nil

  @impl true
  def validate_config(config) do
    case Map.get(config, "mappings") do
      nil -> {:error, ["mappings is required"]}
      m when is_map(m) and map_size(m) > 0 -> :ok
      m when is_binary(m) ->
        case Jason.decode(m) do
          {:ok, parsed} when is_map(parsed) and map_size(parsed) > 0 -> :ok
          _ -> {:error, ["mappings must be a valid JSON object of {output_field: json_path}"]}
        end
      _ -> {:error, ["mappings must be a JSON object of {output_field: json_path}"]}
    end
  end

  @impl true
  def schema do
    %{
      type: "integration/parse_webhook",
      category: "integration",
      label: "Parse Webhook",
      description: "Extracts fields from a webhook payload using dot-separated JSON path mappings.",
      inputs: [
        %{name: "payload", type: "map", required: true}
      ],
      outputs: [
        %{name: "extracted", type: "map"}
      ],
      config_fields: [
        %{name: "mappings", type: "json", default: %{}, description: "JSON object mapping output field names to dot-separated paths in the payload"}
      ]
    }
  end
end
