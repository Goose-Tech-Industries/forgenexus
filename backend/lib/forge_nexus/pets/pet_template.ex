defmodule ForgeNexus.Pets.PetTemplate do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "pet_templates" do
    field :name, :string
    field :slug, :string
    field :description, :string
    field :icon, :string
    field :species, :string
    field :base_stats, :map, default: %{"hunger" => 100, "happiness" => 100, "energy" => 100}
    field :evolution_threshold, :integer
    field :evolves_into_id, :binary_id

    timestamps()
  end

  def changeset(template, attrs) do
    template
    |> cast(attrs, [
      :name,
      :slug,
      :description,
      :icon,
      :species,
      :base_stats,
      :evolution_threshold,
      :evolves_into_id
    ])
    |> validate_required([:name, :slug, :species])
    |> unique_constraint(:slug)
  end
end
