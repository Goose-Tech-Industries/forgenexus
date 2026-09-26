defmodule ForgeNexus.Repo.Migrations.AddSpeciesToPetTemplates do
  use Ecto.Migration

  def change do
    alter table(:pet_templates) do
      add_if_not_exists :species, :string
    end
  end
end
