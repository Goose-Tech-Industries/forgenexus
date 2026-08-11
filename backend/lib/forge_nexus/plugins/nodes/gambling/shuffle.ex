defmodule ForgeNexus.Plugins.Nodes.Gambling.Shuffle do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  @impl true
  def execute(_config, inputs, ctx) do
    items = Map.get(inputs, :items) || Map.get(inputs, "items") || []

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

    shuffled = Enum.shuffle(items)

    {:ok, %{shuffled: shuffled}, ctx}
  end

  @impl true
  def validate_config(_config), do: :ok

  @impl true
  def schema do
    %{
      type: "gambling/shuffle",
      category: "gambling",
      label: "Shuffle",
      description: "Randomly shuffles a list of items.",
      inputs: [
        %{name: "items", type: "list", required: true}
      ],
      outputs: [
        %{name: "shuffled", type: "list"}
      ],
      config_fields: []
    }
  end
end
