defmodule ForgeNexus.Accounts.PromotionRule do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "promotion_rules" do
    field :name, :string
    field :criteria, :map
    field :is_active, :boolean, default: true
    field :position, :integer, default: 0

    belongs_to :from_group, ForgeNexus.Accounts.UserGroup
    belongs_to :to_group, ForgeNexus.Accounts.UserGroup
    timestamps()
  end

  def changeset(rule, attrs) do
    rule
    |> cast(attrs, [:name, :from_group_id, :to_group_id, :criteria, :is_active, :position])
    |> validate_required([:name, :to_group_id, :criteria])
  end
end
