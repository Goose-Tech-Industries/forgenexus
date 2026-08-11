defmodule ForgeNexus.Wiki.WikiRevision do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "wiki_revisions" do
    field :body, :string
    field :body_html, :string
    field :edit_summary, :string
    field :revision_number, :integer
    field :inserted_at, :utc_datetime

    belongs_to :page, ForgeNexus.Wiki.WikiPage
    belongs_to :edited_by, ForgeNexus.Accounts.User
  end

  def changeset(struct, attrs) do
    struct
    |> cast(attrs, [
      :body,
      :body_html,
      :edit_summary,
      :revision_number,
      :inserted_at,
      :page_id,
      :edited_by_id
    ])
    |> validate_required([:body, :revision_number, :page_id, :edited_by_id])
  end
end
