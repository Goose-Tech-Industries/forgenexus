defmodule ForgeNexus.PetsTest do
  use ForgeNexus.DataCase, async: true

  alias ForgeNexus.Pets
  alias ForgeNexus.Pets.{PetTemplate, Pet}
  alias ForgeNexus.Accounts

  defp create_user do
    unique = System.unique_integer([:positive])

    {:ok, user} =
      Accounts.register_user(%{
        username: "pet_u_#{unique}",
        email: "pet_u_#{unique}@example.com",
        password: "ValidPassword123!@#"
      })

    user
  end

  defp template_attrs(attrs \\ %{}) do
    unique = System.unique_integer([:positive])

    Enum.into(attrs, %{
      name: "Dragon #{unique}",
      slug: "dragon-#{unique}",
      species: "Fire Dragon",
      description: "A fiery companion",
      base_stats: %{"hunger" => 80, "happiness" => 90, "energy" => 70}
    })
  end

  describe "pet templates and pet creation" do
    test "list_templates/0, create_pet/3, get_user_pets/1, get_active_pet/1" do
      user = create_user()

      {:ok, tmpl} =
        %PetTemplate{} |> PetTemplate.changeset(template_attrs()) |> ForgeNexus.Repo.insert()

      templates = Pets.list_templates()
      assert Enum.any?(templates, &(&1.id == tmpl.id))

      assert {:ok, %Pet{} = pet} = Pets.create_pet(user.id, tmpl.id, "Draco")
      assert pet.nickname == "Draco"
      assert pet.hunger == 80
      assert pet.happiness == 90
      assert pet.energy == 70

      pets = Pets.get_user_pets(user.id)
      assert length(pets) == 1
      assert hd(pets).pet_template.id == tmpl.id

      # Active pet
      assert is_nil(Pets.get_active_pet(user.id))

      {:ok, _} = pet |> Pet.changeset(%{is_active: true}) |> ForgeNexus.Repo.update()
      assert %Pet{id: id} = Pets.get_active_pet(user.id)
      assert id == pet.id
    end
  end

  describe "pet_action/3" do
    test "rejects non-owner" do
      user = create_user()
      other_user = create_user()

      {:ok, tmpl} =
        %PetTemplate{} |> PetTemplate.changeset(template_attrs()) |> ForgeNexus.Repo.insert()

      {:ok, pet} = Pets.create_pet(user.id, tmpl.id, "Sparky")

      assert {:error, :not_owner} = Pets.pet_action(pet.id, "feed", other_user.id)
    end

    test "handles feed, play, clean, rest, and cooldown" do
      user = create_user()

      {:ok, tmpl} =
        %PetTemplate{}
        |> PetTemplate.changeset(
          template_attrs(%{
            base_stats: %{"hunger" => 50, "happiness" => 50, "energy" => 50}
          })
        )
        |> ForgeNexus.Repo.insert()

      {:ok, pet} = Pets.create_pet(user.id, tmpl.id, "Sparky")

      # Feed action
      assert {:ok, fed} = Pets.pet_action(pet.id, "feed", user.id)
      assert fed.hunger == 75
      assert fed.experience == 5

      # Performing immediately again triggers cooldown
      assert {:error, {:cooldown, _remaining}} = Pets.pet_action(pet.id, "feed", user.id)

      # Play action (different action key, so ready)
      assert {:ok, played} = Pets.pet_action(pet.id, "play", user.id)
      assert played.happiness == 70
      assert played.energy == 40
      assert played.experience == 15

      # Clean action
      assert {:ok, cleaned} = Pets.pet_action(pet.id, "clean", user.id)
      assert cleaned.happiness == 80
      assert cleaned.experience == 18

      # Rest action
      assert {:ok, rested} = Pets.pet_action(pet.id, "rest", user.id)
      assert rested.energy == 70
      assert rested.experience == 20

      # Unknown action
      assert {:ok, unchanged} = Pets.pet_action(pet.id, "unknown_action", user.id)
      assert unchanged.experience == 20
    end
  end

  describe "check_evolution/1" do
    test "returns :no_evolution when no threshold or target is set" do
      user = create_user()

      {:ok, tmpl} =
        %PetTemplate{} |> PetTemplate.changeset(template_attrs()) |> ForgeNexus.Repo.insert()

      {:ok, pet} = Pets.create_pet(user.id, tmpl.id, "EvoPet")

      assert {:ok, :no_evolution} = Pets.check_evolution(pet.id)
    end

    test "handles :not_ready and successful evolution" do
      user = create_user()

      {:ok, stage2} =
        %PetTemplate{}
        |> PetTemplate.changeset(template_attrs(%{name: "Mega Dragon", species: "Fire Lord"}))
        |> ForgeNexus.Repo.insert()

      {:ok, stage1} =
        %PetTemplate{}
        |> PetTemplate.changeset(
          template_attrs(%{
            name: "Baby Dragon",
            evolution_threshold: 100,
            evolves_into_id: stage2.id
          })
        )
        |> ForgeNexus.Repo.insert()

      {:ok, pet} = Pets.create_pet(user.id, stage1.id, "Drake")

      # Not ready: experience 0 < 100
      assert {:ok, :not_ready} = Pets.check_evolution(pet.id)

      # Give enough experience
      {:ok, leveled_pet} = pet |> Pet.changeset(%{experience: 120}) |> ForgeNexus.Repo.update()

      assert {:ok, evolved} = Pets.check_evolution(leveled_pet.id)
      assert evolved.pet_template_id == stage2.id
      assert evolved.level == 2
    end
  end

  describe "breed_pets/3 and decay_stats/0" do
    test "breed_pets/3 requires ownership of both parents and averages stats" do
      user = create_user()
      other_user = create_user()

      {:ok, tmpl} =
        %PetTemplate{} |> PetTemplate.changeset(template_attrs()) |> ForgeNexus.Repo.insert()

      {:ok, pet1} = Pets.create_pet(user.id, tmpl.id, "Father")
      {:ok, pet2} = Pets.create_pet(user.id, tmpl.id, "Mother")
      {:ok, foreign_pet} = Pets.create_pet(other_user.id, tmpl.id, "Stranger")

      # Not owner of both
      assert {:error, :not_owner} = Pets.breed_pets(pet1.id, foreign_pet.id, user.id)

      # Successful breeding
      assert {:ok, %Pet{} = child} = Pets.breed_pets(pet1.id, pet2.id, user.id)
      assert child.user_id == user.id
      assert String.ends_with?(child.nickname, " Jr.")
      assert child.hunger == div(pet1.hunger + pet2.hunger, 2)
    end

    test "decay_stats/0 decreases hunger and happiness and floors at 0" do
      user = create_user()

      {:ok, tmpl} =
        %PetTemplate{}
        |> PetTemplate.changeset(
          template_attrs(%{
            base_stats: %{"hunger" => 3, "happiness" => 2, "energy" => 50}
          })
        )
        |> ForgeNexus.Repo.insert()

      {:ok, pet} = Pets.create_pet(user.id, tmpl.id, "DecayingPet")

      assert {:ok, count} = Pets.decay_stats()
      assert count >= 1

      decayed = ForgeNexus.Repo.get!(Pet, pet.id)
      # 3 - 5 = -2 -> clamped to 0
      assert decayed.hunger == 0
      # 2 - 3 = -1 -> clamped to 0
      assert decayed.happiness == 0
    end
  end
end
