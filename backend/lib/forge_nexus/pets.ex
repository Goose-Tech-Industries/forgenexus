defmodule ForgeNexus.Pets do
  @moduledoc "Virtual pets with stats, evolution, breeding, and decay."
  import Ecto.Query
  alias ForgeNexus.Repo
  alias ForgeNexus.Pets.{PetTemplate, Pet}
  alias ForgeNexus.Cooldowns

  def list_templates, do: PetTemplate |> order_by(:name) |> Repo.all()

  def create_pet(user_id, pet_template_id, nickname) do
    template = Repo.get!(PetTemplate, pet_template_id)
    %Pet{}
    |> Pet.changeset(%{
      user_id: user_id,
      pet_template_id: pet_template_id,
      nickname: nickname,
      hunger: Map.get(template.base_stats, "hunger", 100),
      happiness: Map.get(template.base_stats, "happiness", 100),
      energy: Map.get(template.base_stats, "energy", 100)
    })
    |> Repo.insert()
  end

  def get_user_pets(user_id) do
    Pet |> where([p], p.user_id == ^user_id) |> preload(:pet_template) |> order_by(:inserted_at) |> Repo.all()
  end

  def get_active_pet(user_id) do
    Repo.one(from p in Pet, where: p.user_id == ^user_id and p.is_active == true, preload: :pet_template, limit: 1)
  end

  def pet_action(pet_id, action_type, user_id) do
    pet = Repo.get!(Pet, pet_id)
    if pet.user_id != user_id, do: {:error, :not_owner}
    cooldown_key = "pet_action:" <> action_type <> ":" <> pet_id
    case Cooldowns.check_cooldown(user_id, cooldown_key) do
      {:error, remaining} -> {:error, {:cooldown, remaining}}
      {:ok, :ready} ->
        changes = case action_type do
          "feed" -> %{hunger: min(pet.hunger + 25, 100), experience: pet.experience + 5}
          "play" -> %{happiness: min(pet.happiness + 20, 100), energy: max(pet.energy - 10, 0), experience: pet.experience + 10}
          "clean" -> %{happiness: min(pet.happiness + 10, 100), experience: pet.experience + 3}
          "rest" -> %{energy: min(pet.energy + 30, 100), experience: pet.experience + 2}
          _ -> %{}
        end
        Cooldowns.set_cooldown(user_id, cooldown_key, 300)
        pet |> Pet.changeset(changes) |> Repo.update()
    end
  end

  def check_evolution(pet_id) do
    pet = Repo.get!(Pet, pet_id) |> Repo.preload(:pet_template)
    template = pet.pet_template
    cond do
      is_nil(template.evolution_threshold) -> {:ok, :no_evolution}
      is_nil(template.evolves_into_id) -> {:ok, :no_evolution}
      pet.experience < template.evolution_threshold -> {:ok, :not_ready}
      true ->
        new_template = Repo.get!(PetTemplate, template.evolves_into_id)
        pet
        |> Pet.changeset(%{pet_template_id: new_template.id, level: pet.level + 1})
        |> Repo.update()
    end
  end

  def breed_pets(pet1_id, pet2_id, user_id) do
    pet1 = Repo.get!(Pet, pet1_id) |> Repo.preload(:pet_template)
    pet2 = Repo.get!(Pet, pet2_id) |> Repo.preload(:pet_template)
    if pet1.user_id != user_id or pet2.user_id != user_id, do: {:error, :not_owner}
    avg_hunger = div(pet1.hunger + pet2.hunger, 2)
    avg_happiness = div(pet1.happiness + pet2.happiness, 2)
    avg_energy = div(pet1.energy + pet2.energy, 2)
    parent_template = Enum.random([pet1.pet_template, pet2.pet_template])
    nickname = parent_template.name <> " Jr."
    %Pet{}
    |> Pet.changeset(%{
      user_id: user_id,
      pet_template_id: parent_template.id,
      nickname: nickname,
      hunger: avg_hunger,
      happiness: avg_happiness,
      energy: avg_energy
    })
    |> Repo.insert()
  end

  def decay_stats do
    _now = DateTime.utc_now()
    {count, _} = from(p in Pet)
    |> Repo.update_all(inc: [hunger: -5, happiness: -3])

    from(p in Pet, where: p.hunger < 0) |> Repo.update_all(set: [hunger: 0])
    from(p in Pet, where: p.happiness < 0) |> Repo.update_all(set: [happiness: 0])
    {:ok, count}
  end
end
