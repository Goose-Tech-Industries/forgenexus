defmodule ForgeNexus.Plugins.Nodes.Gambling.WeightedPick do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  @impl true
  def execute(config, _inputs, ctx) do
    items = Map.get(config, "items", [])

    items =
      cond do
        is_list(items) ->
          items

        is_binary(items) ->
          try do
            Jason.decode!(items)
          rescue
            _ -> []
          end

        true ->
          []
      end

    if items == [] do
      {:error, "items list is empty", ctx}
    else
      total_weight =
        Enum.reduce(items, 0, fn item, acc ->
          acc + (Map.get(item, "weight") || Map.get(item, :weight) || 1)
        end)

      roll = :rand.uniform() * total_weight

      {result, index} = pick_weighted(items, roll, 0, 0)

      {:ok, %{result: result, index: index}, ctx}
    end
  end

  defp pick_weighted([item | rest], roll, cumulative, index) do
    weight = Map.get(item, "weight") || Map.get(item, :weight) || 1
    cumulative = cumulative + weight

    if roll <= cumulative do
      label = Map.get(item, "label") || Map.get(item, :label) || "item_#{index}"
      {label, index}
    else
      pick_weighted(rest, roll, cumulative, index + 1)
    end
  end

  defp pick_weighted([], _roll, _cumulative, index) do
    {"unknown", index - 1}
  end

  @impl true
  def validate_config(config) do
    case Map.get(config, "items") do
      nil ->
        {:error, ["items is required"]}

      items when is_list(items) and length(items) > 0 ->
        :ok

      items when is_binary(items) ->
        case Jason.decode(items) do
          {:ok, list} when is_list(list) and length(list) > 0 -> :ok
          _ -> {:error, ["items must be a non-empty JSON array"]}
        end

      _ ->
        {:error, ["items must be a non-empty list of {label, weight} objects"]}
    end
  end

  @impl true
  def schema do
    %{
      type: "gambling/weighted_pick",
      category: "gambling",
      label: "Weighted Pick",
      description: "Picks a random item from a weighted list.",
      inputs: [],
      outputs: [
        %{name: "result", type: "string"},
        %{name: "index", type: "number"}
      ],
      config_fields: [
        %{
          name: "items",
          type: "json",
          default: "[]",
          description: "JSON array of {label, weight} objects"
        }
      ]
    }
  end
end
