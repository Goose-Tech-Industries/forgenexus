defmodule ForgeNexus.Forums.PostRating do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @rating_types ~w(like agree disagree informative funny winner useful)

  schema "post_ratings" do
    field :rating_type, :string
    belongs_to :post, ForgeNexus.Forums.Post
    belongs_to :user, ForgeNexus.Accounts.User
    timestamps()
  end

  def changeset(rating, attrs) do
    rating
    |> cast(attrs, [:post_id, :user_id, :rating_type])
    |> validate_required([:post_id, :user_id, :rating_type])
    |> validate_inclusion(:rating_type, @rating_types)
    |> unique_constraint([:post_id, :user_id, :rating_type])
  end

  def rating_types, do: @rating_types
end
