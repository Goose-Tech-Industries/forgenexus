defmodule ForgeNexus.Collections.CollectionItem do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "collection_items" do
    field :name, :string
    field :description, :string
    field :icon, :string
    field :rarity, :string, default: "common"
    field :sort_order, :integer, default: 0

    belongs_to :collection_set, ForgeNexus.Collections.CollectionSet

    timestamps()
  end

  def changeset(item, attrs) do
    item
    |> cast(attrs, [:name, :description, :icon, :rarity, :sort_order, :collection_set_id])
    |> validate_required([:name, :collection_set_id])
  end
end
