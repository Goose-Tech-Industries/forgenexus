defmodule ForgeNexus.Accounts.UserFollow do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "user_follows" do
    belongs_to :follower, ForgeNexus.Accounts.User
    belongs_to :followed, ForgeNexus.Accounts.User

    timestamps()
  end

  def changeset(follow, attrs) do
    follow
    |> cast(attrs, [:follower_id, :followed_id])
    |> validate_required([:follower_id, :followed_id])
    |> unique_constraint([:follower_id, :followed_id])
    |> check_constraint(:followed_id, name: :no_self_follow, message: "cannot follow yourself")
  end
end
