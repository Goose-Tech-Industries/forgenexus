defmodule ForgeNexus.Communities.CommunityMember do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @roles ~w(member moderator admin owner)

  schema "community_members" do
    field :role, :string, default: "member"
    field :joined_at, :utc_datetime

    belongs_to :community, ForgeNexus.Communities.Community
    belongs_to :user, ForgeNexus.Accounts.User

    timestamps()
  end

  def changeset(member, attrs) do
    member
    |> cast(attrs, [:community_id, :user_id, :role, :joined_at])
    |> validate_required([:community_id, :user_id])
    |> validate_inclusion(:role, @roles)
    |> unique_constraint([:community_id, :user_id])
  end
end
