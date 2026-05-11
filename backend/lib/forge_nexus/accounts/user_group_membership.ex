defmodule ForgeNexus.Accounts.UserGroupMembership do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "user_group_memberships" do
    belongs_to :user, ForgeNexus.Accounts.User
    belongs_to :group, ForgeNexus.Accounts.UserGroup

    timestamps()
  end

  def changeset(membership, attrs) do
    membership
    |> cast(attrs, [:user_id, :group_id])
    |> validate_required([:user_id, :group_id])
    |> unique_constraint([:user_id, :group_id])
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:group_id)
  end
end
