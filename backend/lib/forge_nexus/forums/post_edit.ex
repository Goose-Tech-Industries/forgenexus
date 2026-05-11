defmodule ForgeNexus.Forums.PostEdit do
  use Ecto.Schema

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "post_edits" do
    field :body_before, :string
    field :body_after, :string
    field :edit_reason, :string

    belongs_to :post, ForgeNexus.Forums.Post
    belongs_to :editor, ForgeNexus.Accounts.User, foreign_key: :edited_by_id

    timestamps(updated_at: false)
  end
end
