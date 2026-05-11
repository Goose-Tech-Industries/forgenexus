defmodule ForgeNexus.Collections.CollectionSet do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "collection_sets" do
    field :name, :string
    field :description, :string
    field :icon, :string
    field :reward_points, :integer, default: 0
    field :reward_badge_id, :binary_id
    field :is_active, :boolean, default: true

    has_many :items, ForgeNexus.Collections.CollectionItem

    timestamps()
  end

  def changeset(set, attrs) do
    set
    |> cast(attrs, [:name, :description, :icon, :reward_points, :reward_badge_id, :is_active])
    |> validate_required([:name])
  end
end
