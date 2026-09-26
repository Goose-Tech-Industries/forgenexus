defmodule ForgeNexus.Forums.PostEdit do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "post_edits" do
    field :body_before, :string
    field :body_after, :string
    field :reason, :string

    belongs_to :post, ForgeNexus.Forums.Post
    belongs_to :editor, ForgeNexus.Accounts.User, foreign_key: :user_id

    timestamps()
  end

  def changeset(post_edit, attrs) do
    post_edit
    |> cast(attrs, [:body_before, :body_after, :reason, :post_id, :user_id])
    |> validate_required([:body_before, :body_after, :post_id, :user_id])
  end
end
