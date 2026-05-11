defmodule ForgeNexus.Forums.ThreadRating do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "thread_ratings" do
    field :rating, :integer

    belongs_to :user, ForgeNexus.Accounts.User
    belongs_to :thread, ForgeNexus.Forums.Thread

    timestamps()
  end

  def changeset(rating, attrs) do
    rating
    |> cast(attrs, [:rating, :user_id, :thread_id])
    |> validate_required([:rating, :user_id, :thread_id])
    |> validate_number(:rating, greater_than_or_equal_to: 1, less_than_or_equal_to: 5)
    |> unique_constraint([:user_id, :thread_id])
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:thread_id)
  end
end
