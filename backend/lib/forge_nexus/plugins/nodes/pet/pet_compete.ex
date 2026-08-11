defmodule ForgeNexus.Plugins.Nodes.Pet.PetCompete do
  @behaviour ForgeNexus.Plugins.Nodes.Behaviour

  alias ForgeNexus.Plugins.Engine.Sandbox
  alias ForgeNexus.Repo
  alias ForgeNexus.Pets.Pet

  @impl true
  def execute(config, inputs, ctx) do
    Sandbox.check_db_limit!(ctx)

    pet_id = Map.get(inputs, :pet_id) || Map.get(inputs, "pet_id")
    competition_type = Map.get(config, "competition_type", "overall")

    case Repo.get(Pet, pet_id) do
      nil ->
        ctx = Sandbox.increment_db_ops(ctx)
        {:error, "Pet not found", ctx}

      pet ->
        ctx = Sandbox.increment_db_ops(ctx)

        score =
          case competition_type do
            "beauty" ->
              (pet.happiness || 0) + (pet.health || 0)

            "strength" ->
              (pet.level || 0) * 10 + (pet.experience || 0)

            "speed" ->
              (pet.energy || 0) + (pet.level || 0) * 5

            _ ->
              (pet.level || 0) * 10 + (pet.experience || 0) + (pet.happiness || 0) +
                (pet.health || 0)
          end

        {:ok,
         %{
           score: score,
           pet: %{id: pet.id, nickname: pet.nickname, level: pet.level}
         }, ctx}
    end
  end

  @impl true
  def validate_config(config) do
    ct = Map.get(config, "competition_type", "overall")

    if ct in ~w(beauty strength speed overall) do
      :ok
    else
      {:error, ["competition_type must be one of: beauty, strength, speed, overall"]}
    end
  end

  @impl true
  def schema do
    %{
      type: "pet/pet_compete",
      category: "pet",
      label: "Pet Compete",
      description: "Enters a pet into a competition and returns its score and ranking.",
      inputs: [
        %{name: "pet_id", type: "string", required: true}
      ],
      outputs: [
        %{name: "score", type: "number"},
        %{name: "rank", type: "number"},
        %{name: "total_entries", type: "number"}
      ],
      config_fields: [
        %{
          name: "competition_type",
          type: "select",
          options: ~w(beauty strength speed overall),
          default: "overall",
          description: "Type of competition to enter"
        }
      ]
    }
  end
end
