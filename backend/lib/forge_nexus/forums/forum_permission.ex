defmodule ForgeNexus.Forums.ForumPermission do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "forum_permissions" do
    field :can_view, :boolean, default: true
    field :can_post, :boolean, default: true
    field :can_create_threads, :boolean, default: true

    belongs_to :forum, ForgeNexus.Forums.Forum
    belongs_to :group, ForgeNexus.Accounts.UserGroup

    timestamps()
  end

  def changeset(permission, attrs) do
    permission
    |> cast(attrs, [:forum_id, :group_id, :can_view, :can_post, :can_create_threads])
    |> validate_required([:forum_id, :group_id])
    |> unique_constraint([:forum_id, :group_id])
    |> foreign_key_constraint(:forum_id)
    |> foreign_key_constraint(:group_id)
  end
end
