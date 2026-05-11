defmodule ForgeNexus.Profiles.TopFriend do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "profile_top_friends" do
    field :position, :integer

    belongs_to :user, ForgeNexus.Accounts.User
    belongs_to :friend, ForgeNexus.Accounts.User

    timestamps()
  end

  def changeset(top_friend, attrs) do
    top_friend
    |> cast(attrs, [:user_id, :friend_id, :position])
    |> validate_required([:user_id, :friend_id, :position])
    |> validate_number(:position, greater_than_or_equal_to: 0, less_than: 10)
    |> unique_constraint([:user_id, :friend_id])
  end
end
