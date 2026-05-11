defmodule ForgeNexus.Economy.PointPack do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "point_packs" do
    field :name, :string
    field :points, :integer
    field :bonus_points, :integer, default: 0
    field :price_cents, :integer
    field :currency, :string, default: "usd"
    field :is_active, :boolean, default: true
    field :position, :integer, default: 0
    field :emoji, :string

    belongs_to :community, ForgeNexus.Communities.Community

    timestamps()
  end

  def changeset(pack, attrs) do
    pack
    |> cast(attrs, [:community_id, :name, :points, :bonus_points, :price_cents, :currency, :is_active, :position, :emoji])
    |> validate_required([:name, :points, :price_cents])
    |> validate_number(:points, greater_than: 0)
    |> validate_number(:price_cents, greater_than: 0)
    |> validate_number(:bonus_points, greater_than_or_equal_to: 0)
  end

  def total_points(%__MODULE__{points: p, bonus_points: b}), do: p + (b || 0)
end
