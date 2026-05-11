defmodule ForgeNexus.Inventory.CraftingRecipe do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "crafting_recipes" do
    field :name, :string
    field :description, :string
    field :success_rate, :float, default: 1.0
    field :ingredients, {:array, :map}, default: []
    field :is_active, :boolean, default: true

    belongs_to :result_item, ForgeNexus.Inventory.ItemTemplate
    field :result_quantity, :integer, default: 1

    timestamps()
  end

  def changeset(recipe, attrs) do
    recipe
    |> cast(attrs, [:name, :description, :success_rate, :ingredients, :result_item_id, :result_quantity, :is_active])
    |> validate_required([:name, :ingredients, :result_item_id])
    |> validate_number(:success_rate, greater_than: 0.0, less_than_or_equal_to: 1.0)
  end
end
