defmodule ForgeNexus.Inventory.ItemTemplate do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "item_templates" do
    field :name, :string
    field :slug, :string
    field :description, :string
    field :icon, :string
    field :category, :string
    field :rarity, :string, default: "common"
    field :is_stackable, :boolean, default: true
    field :is_tradeable, :boolean, default: true
    field :is_consumable, :boolean, default: false
    field :is_equippable, :boolean, default: false
    field :max_stack, :integer, default: 99
    field :properties, :map, default: %{}

    timestamps()
  end

  def changeset(template, attrs) do
    template
    |> cast(attrs, [
      :name,
      :slug,
      :description,
      :icon,
      :category,
      :rarity,
      :is_stackable,
      :is_tradeable,
      :is_consumable,
      :is_equippable,
      :max_stack,
      :properties
    ])
    |> validate_required([:name, :slug])
    |> validate_inclusion(:rarity, ~w(common uncommon rare epic legendary))
    |> unique_constraint(:slug)
  end
end
