defmodule ForgeNexus.Pets.Pet do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "pets" do
    field :nickname, :string
    field :experience, :integer, default: 0
    field :level, :integer, default: 1
    field :hunger, :integer, default: 100
    field :happiness, :integer, default: 100
    field :energy, :integer, default: 100
    field :is_active, :boolean, default: false

    belongs_to :user, ForgeNexus.Accounts.User
    belongs_to :pet_template, ForgeNexus.Pets.PetTemplate

    timestamps()
  end

  def changeset(pet, attrs) do
    pet
    |> cast(attrs, [:nickname, :experience, :level, :hunger, :happiness, :energy, :is_active, :user_id, :pet_template_id])
    |> validate_required([:nickname, :user_id, :pet_template_id])
    |> validate_number(:hunger, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
    |> validate_number(:happiness, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
    |> validate_number(:energy, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
  end
end
