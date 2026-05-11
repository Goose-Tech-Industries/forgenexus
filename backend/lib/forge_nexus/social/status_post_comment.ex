defmodule ForgeNexus.Social.StatusPostComment do
  use Ecto.Schema

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "status_post_comments" do
    field :body, :string
    belongs_to :status_post, ForgeNexus.Social.StatusPost
    belongs_to :user, ForgeNexus.Accounts.User
    timestamps()
  end
end
