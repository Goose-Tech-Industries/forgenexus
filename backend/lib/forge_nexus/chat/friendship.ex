defmodule ForgeNexus.Chat.Friendship do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "friendships" do
    field :status, :string, default: "pending"

    belongs_to :user, ForgeNexus.Accounts.User
    belongs_to :friend, ForgeNexus.Accounts.User

    timestamps()
  end

  def changeset(friendship, attrs) do
    friendship
    |> cast(attrs, [:status, :user_id, :friend_id])
    |> validate_required([:user_id, :friend_id])
    |> validate_inclusion(:status, ["pending", "accepted", "declined"])
    |> unique_constraint([:user_id, :friend_id])
    |> validate_not_self_friend()
  end

  defp validate_not_self_friend(changeset) do
    user_id = get_field(changeset, :user_id)
    friend_id = get_field(changeset, :friend_id)

    if user_id && friend_id && user_id == friend_id do
      add_error(changeset, :friend_id, "cannot be yourself")
    else
      changeset
    end
  end
end
