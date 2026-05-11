defmodule ForgeNexus.Plugins.Nodes.Logic.Random do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  @impl true
  def execute(config, _inputs, ctx) do
    branches = Map.get(config, "branches", [])
    weights = Map.get(config, "weights", [])

    cond do
      branches == [] ->
        {:error, "No branches configured", ctx}

      true ->
        # Normalize weights: if missing or wrong length, use equal weights
        effective_weights =
          if is_list(weights) and length(weights) == length(branches) do
            weights
          else
            List.duplicate(1, length(branches))
          end

        selected = weighted_random(branches, effective_weights)
        {:branch, selected, %{}, ctx}
    end
  end

  defp weighted_random(branches, weights) do
    total = Enum.sum(weights)
    roll = :rand.uniform() * total

    {selected, _} =
      branches
      |> Enum.zip(weights)
      |> Enum.reduce_while({nil, 0}, fn {branch, weight}, {_selected, acc} ->
        new_acc = acc + weight

        if roll <= new_acc do
          {:halt, {branch, new_acc}}
        else
          {:cont, {branch, new_acc}}
        end
      end)

    selected || List.last(branches)
  end

  @impl true
  def validate_config(config) do
    if is_list(Map.get(config, "branches")) and length(Map.get(config, "branches", [])) > 0 do
      :ok
    else
      {:error, ["branches must be a non-empty list"]}
    end
  end

  @impl true
  def schema do
    %{
      type: "logic/random",
      category: "logic",
      label: "Random Branch",
      description: "Routes to a random branch with optional weights.",
      inputs: [],
      outputs: [%{name: "selected", type: "string"}],
      config_fields: [
        %{name: "branches", type: "json", default: [], description: "List of branch port names"},
        %{name: "weights", type: "json", default: [], description: "Optional weights for each branch"}
      ]
    }
  end
end
