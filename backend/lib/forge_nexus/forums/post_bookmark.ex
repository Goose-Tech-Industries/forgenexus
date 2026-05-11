defmodule ForgeNexus.Forums.PostBookmark do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "post_bookmarks" do
    belongs_to :post, ForgeNexus.Forums.Post
    belongs_to :user, ForgeNexus.Accounts.User
    field :note, :string

    timestamps()
  end

  def changeset(bookmark, attrs) do
    bookmark
    |> cast(attrs, [:post_id, :user_id, :note])
    |> validate_required([:post_id, :user_id])
    |> unique_constraint([:post_id, :user_id])
  end
end
