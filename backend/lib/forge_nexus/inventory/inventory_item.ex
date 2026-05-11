defmodule ForgeNexus.Inventory.InventoryItem do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "inventory_items" do
    field :quantity, :integer, default: 1
    field :is_equipped, :boolean, default: false
    field :metadata, :map, default: %{}

    belongs_to :user, ForgeNexus.Accounts.User
    belongs_to :item_template, ForgeNexus.Inventory.ItemTemplate

    timestamps()
  end

  def changeset(item, attrs) do
    item
    |> cast(attrs, [:user_id, :item_template_id, :quantity, :is_equipped, :metadata])
    |> validate_required([:user_id, :item_template_id, :quantity])
    |> validate_number(:quantity, greater_than: 0)
  end
end
