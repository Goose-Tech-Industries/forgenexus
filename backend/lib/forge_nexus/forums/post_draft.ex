defmodule ForgeNexus.Forums.PostDraft do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "post_drafts" do
    field :context_type, :string
    field :context_id, :string
    field :title, :string
    field :body, :string

    belongs_to :user, ForgeNexus.Accounts.User

    timestamps()
  end

  def changeset(draft, attrs) do
    draft
    |> cast(attrs, [:user_id, :context_type, :context_id, :title, :body])
    |> validate_required([:user_id, :context_type, :body])
    |> validate_inclusion(:context_type, ["thread_create", "thread_reply", "dm"])
    |> unique_constraint([:user_id, :context_type, :context_id])
  end
end
