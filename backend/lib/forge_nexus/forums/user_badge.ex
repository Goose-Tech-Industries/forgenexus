defmodule ForgeNexus.Forums.UserBadge do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "user_badges" do
    belongs_to :user, ForgeNexus.Accounts.User
    belongs_to :badge, ForgeNexus.Forums.Badge
    belongs_to :awarded_by, ForgeNexus.Accounts.User
    field :reason, :string
    field :is_featured, :boolean, default: false

    timestamps()
  end

  def changeset(ub, attrs) do
    ub
    |> cast(attrs, [:user_id, :badge_id, :awarded_by_id, :reason, :is_featured])
    |> validate_required([:user_id, :badge_id])
    |> unique_constraint([:user_id, :badge_id])
  end
end
