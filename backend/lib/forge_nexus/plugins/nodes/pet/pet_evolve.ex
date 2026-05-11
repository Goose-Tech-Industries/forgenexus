defmodule ForgeNexus.Plugins.Nodes.Pet.PetEvolve do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox

  @impl true
  def execute(_config, inputs, ctx) do
    Sandbox.check_db_limit!(ctx)

    pet_id = Map.get(inputs, :pet_id) || Map.get(inputs, "pet_id")

    case ForgeNexus.Pets.check_evolution(pet_id) do
      {:ok, :no_evolution} ->
        ctx = Sandbox.increment_db_ops(ctx)

        {:branch, "not_ready",
         %{
           evolved: false,
           reason: :no_evolution
         }, ctx}

      {:ok, :not_ready} ->
        ctx = Sandbox.increment_db_ops(ctx)

        {:branch, "not_ready",
         %{
           evolved: false,
           reason: :not_ready
         }, ctx}

      {:ok, pet} ->
        ctx = Sandbox.increment_db_ops(ctx)

        {:branch, "evolved",
         %{
           evolved: true,
           pet: %{id: pet.id, nickname: pet.nickname, level: pet.level, template_id: pet.template_id}
         }, ctx}

      {:error, reason} ->
        ctx = Sandbox.increment_db_ops(ctx)
        {:error, "Failed to check evolution: #{inspect(reason)}", ctx}
    end
  end

  @impl true
  def validate_config(_config), do: :ok

  @impl true
  def schema do
    %{
      type: "pet/pet_evolve",
      category: "pet",
      label: "Pet Evolve",
      description: "Attempts to evolve a pet, branching on whether evolution conditions are met.",
      inputs: [
        %{name: "pet_id", type: "string", required: true}
      ],
      outputs: [
        %{name: "evolved", type: "map"},
        %{name: "not_ready", type: "map"}
      ],
      config_fields: []
    }
  end
end
