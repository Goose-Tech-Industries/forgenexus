defmodule ForgeNexus.Forums.ContentIgnore do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "content_ignores" do
    belongs_to :user, ForgeNexus.Accounts.User
    belongs_to :forum, ForgeNexus.Forums.Forum
    belongs_to :thread, ForgeNexus.Forums.Thread

    timestamps()
  end

  def changeset(ignore, attrs) do
    ignore
    |> cast(attrs, [:user_id, :forum_id, :thread_id])
    |> validate_required([:user_id])
    |> validate_has_target()
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:forum_id)
    |> foreign_key_constraint(:thread_id)
    |> unique_constraint([:user_id, :forum_id], name: :content_ignores_user_forum)
    |> unique_constraint([:user_id, :thread_id], name: :content_ignores_user_thread)
  end

  defp validate_has_target(changeset) do
    forum_id = get_field(changeset, :forum_id)
    thread_id = get_field(changeset, :thread_id)

    if is_nil(forum_id) and is_nil(thread_id) do
      add_error(changeset, :forum_id, "must ignore either a forum or a thread")
    else
      changeset
    end
  end
end
