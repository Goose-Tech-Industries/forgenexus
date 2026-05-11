defmodule ForgeNexus.Plugins.Nodes.Gambling.PickFromTable do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  @impl true
  def execute(config, inputs, ctx) do
    items = Map.get(inputs, :items) || Map.get(inputs, "items") || []
    count = Map.get(config, "count", 1) |> to_integer()

    items =
      cond do
        is_list(items) -> items
        is_binary(items) -> (try do Jason.decode!(items) rescue _ -> [] end)
        true -> []
      end

    if items == [] do
      {:error, "items list is empty", ctx}
    else
      count = min(count, length(items))
      picked = items |> Enum.shuffle() |> Enum.take(count)
      {:ok, %{picked: picked}, ctx}
    end
  end

  defp to_integer(val) when is_integer(val), do: val
  defp to_integer(val) when is_float(val), do: trunc(val)

  defp to_integer(val) when is_binary(val) do
    case Integer.parse(val) do
      {n, _} -> n
      :error -> 1
    end
  end

  defp to_integer(_), do: 1

  @impl true
  def validate_config(_config), do: :ok

  @impl true
  def schema do
    %{
      type: "gambling/pick_from_table",
      category: "gambling",
      label: "Pick from Table",
      description: "Randomly picks items from a list.",
      inputs: [
        %{name: "items", type: "list", required: true}
      ],
      outputs: [
        %{name: "picked", type: "list"}
      ],
      config_fields: [
        %{name: "count", type: "number", default: 1, description: "Number of items to pick"}
      ]
    }
  end
end
