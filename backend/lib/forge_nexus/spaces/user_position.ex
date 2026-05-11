defmodule ForgeNexus.Spaces.UserPosition do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "user_map_positions" do
    field :x, :float
    field :y, :float
    field :last_moved_at, :utc_datetime

    belongs_to :user, ForgeNexus.Accounts.User
    belongs_to :map, ForgeNexus.Spaces.CommunityMap
    belongs_to :room, ForgeNexus.Spaces.MapRoom

    timestamps(type: :utc_datetime)
  end

  def changeset(struct, attrs) do
    struct
    |> cast(attrs, [:x, :y, :last_moved_at, :user_id, :map_id, :room_id])
    |> validate_required([:x, :y, :user_id, :map_id])
  end
end
