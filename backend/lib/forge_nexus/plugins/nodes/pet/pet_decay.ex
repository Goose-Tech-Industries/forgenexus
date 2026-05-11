defmodule ForgeNexus.Plugins.Nodes.Pet.PetDecay do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox

  @impl true
  def execute(_config, _inputs, ctx) do
    Sandbox.check_db_limit!(ctx)

    case ForgeNexus.Pets.decay_stats() do
      {:ok, count} ->
        ctx = Sandbox.increment_db_ops(ctx)
        {:ok, %{pets_affected: count}, ctx}

      {:error, reason} ->
        ctx = Sandbox.increment_db_ops(ctx)
        {:error, "Failed to apply pet decay: #{inspect(reason)}", ctx}
    end
  end

  @impl true
  def validate_config(config) do
    errors =
      []
      |> then(fn e ->
        hr = Map.get(config, "hunger_rate")
        if is_nil(hr) or (is_number(hr) and hr >= 0), do: e, else: ["hunger_rate must be a non-negative number" | e]
      end)
      |> then(fn e ->
        hr = Map.get(config, "happiness_rate")
        if is_nil(hr) or (is_number(hr) and hr >= 0), do: e, else: ["happiness_rate must be a non-negative number" | e]
      end)

    if errors == [], do: :ok, else: {:error, errors}
  end

  @impl true
  def schema do
    %{
      type: "pet/pet_decay",
      category: "pet",
      label: "Pet Decay",
      description: "Reduces hunger and happiness stats for all active pets as a scheduled job.",
      inputs: [],
      outputs: [
        %{name: "pets_affected", type: "number"}
      ],
      config_fields: [
        %{name: "hunger_rate", type: "number", default: 5, description: "Amount to reduce hunger per tick"},
        %{name: "happiness_rate", type: "number", default: 3, description: "Amount to reduce happiness per tick"}
      ]
    }
  end
end
