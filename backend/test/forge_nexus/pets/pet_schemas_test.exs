defmodule ForgeNexus.Pets.PetSchemasTest do
  use ForgeNexus.DataCase, async: true

  alias ForgeNexus.Pets.{Pet, PetTemplate}

  describe "Pet" do
    @uid Ecto.UUID.generate()
    @ptid Ecto.UUID.generate()

    test "valid changeset" do
      cs =
        Pet.changeset(%Pet{}, %{
          nickname: "Sparky",
          user_id: @uid,
          pet_template_id: @ptid,
          hunger: 80,
          happiness: 90,
          energy: 70
        })

      assert cs.valid?
      assert get_field(cs, :nickname) == "Sparky"
      assert get_field(cs, :hunger) == 80
    end

    test "validates required fields" do
      cs = Pet.changeset(%Pet{}, %{})
      refute cs.valid?
      assert "can't be blank" in errors_on(cs).nickname
      assert "can't be blank" in errors_on(cs).user_id
      assert "can't be blank" in errors_on(cs).pet_template_id
    end

    test "validates stats bounds (0 to 100)" do
      bad_cs =
        Pet.changeset(%Pet{}, %{
          nickname: "Sparky",
          user_id: @uid,
          pet_template_id: @ptid,
          hunger: 101,
          happiness: -1,
          energy: 150
        })

      refute bad_cs.valid?
      assert "must be less than or equal to 100" in errors_on(bad_cs).hunger
      assert "must be greater than or equal to 0" in errors_on(bad_cs).happiness
      assert "must be less than or equal to 100" in errors_on(bad_cs).energy
    end
  end

  describe "PetTemplate" do
    test "valid changeset" do
      cs =
        PetTemplate.changeset(%PetTemplate{}, %{
          name: "Fire Fox",
          slug: "fire-fox",
          species: "fox",
          evolution_threshold: 50
        })

      assert cs.valid?
      assert get_field(cs, :slug) == "fire-fox"

      req_cs = PetTemplate.changeset(%PetTemplate{}, %{})
      refute req_cs.valid?
      assert "can't be blank" in errors_on(req_cs).name
      assert "can't be blank" in errors_on(req_cs).slug
      assert "can't be blank" in errors_on(req_cs).species
    end
  end
end
