defmodule ForgeNexus.Spaces.MapRoom do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "map_rooms" do
    field :name, :string
    field :type, :string
    field :linked_resource_type, :string
    field :linked_resource_id, :binary_id
    field :x, :integer
    field :y, :integer
    field :width, :integer
    field :height, :integer
    field :shape, :string, default: "rect"
    field :style, :map, default: %{}
    field :max_occupancy, :integer
    field :config, :map, default: %{}

    belongs_to :map, ForgeNexus.Spaces.CommunityMap

    timestamps(type: :utc_datetime)
  end

  def changeset(struct, attrs) do
    struct
    |> cast(attrs, [:name, :type, :linked_resource_type, :linked_resource_id, :x, :y, :width, :height, :shape, :style, :max_occupancy, :config, :map_id])
    |> validate_required([:name, :x, :y, :width, :height, :map_id])
  end
end
