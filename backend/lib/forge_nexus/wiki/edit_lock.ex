defmodule ForgeNexus.Wiki.EditLock do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "wiki_edit_locks" do
    field :locked_at, :utc_datetime
    field :expires_at, :utc_datetime

    belongs_to :page, ForgeNexus.Wiki.WikiPage
    belongs_to :user, ForgeNexus.Accounts.User
  end

  def changeset(struct, attrs) do
    struct
    |> cast(attrs, [:locked_at, :expires_at, :page_id, :user_id])
    |> validate_required([:locked_at, :expires_at, :page_id, :user_id])
  end
end
