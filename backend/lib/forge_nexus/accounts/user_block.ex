defmodule ForgeNexus.Accounts.UserBlock do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "user_blocks" do
    belongs_to :user, ForgeNexus.Accounts.User
    belongs_to :blocked_user, ForgeNexus.Accounts.User

    timestamps()
  end

  def changeset(block, attrs) do
    block
    |> cast(attrs, [:user_id, :blocked_user_id])
    |> validate_required([:user_id, :blocked_user_id])
    |> unique_constraint([:user_id, :blocked_user_id])
  end
end
