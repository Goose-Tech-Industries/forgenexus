defmodule ForgeNexus.Plugins.Nodes.Pet.GetPetStats do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox
  alias ForgeNexus.Repo
  alias ForgeNexus.Pets.Pet

  @impl true
  def execute(_config, inputs, ctx) do
    Sandbox.check_db_limit!(ctx)

    pet_id = Map.get(inputs, :pet_id) || Map.get(inputs, "pet_id")

    case Repo.get(Pet, pet_id) do
      nil ->
        ctx = Sandbox.increment_db_ops(ctx)
        {:error, "Pet not found", ctx}

      pet ->
        ctx = Sandbox.increment_db_ops(ctx)

        {:ok,
         %{
           stats: %{
             hunger: pet.hunger,
             happiness: pet.happiness,
             health: pet.health,
             energy: pet.energy
           },
           level: pet.level,
           experience: pet.experience,
           nickname: pet.nickname
         }, ctx}
    end
  end

  @impl true
  def validate_config(_config), do: :ok

  @impl true
  def schema do
    %{
      type: "pet/get_pet_stats",
      category: "pet",
      label: "Get Pet Stats",
      description: "Retrieves a pet's current stats, level, and experience.",
      inputs: [
        %{name: "pet_id", type: "string", required: true}
      ],
      outputs: [
        %{name: "stats", type: "map"},
        %{name: "level", type: "number"},
        %{name: "experience", type: "number"},
        %{name: "nickname", type: "string"}
      ],
      config_fields: []
    }
  end
end
