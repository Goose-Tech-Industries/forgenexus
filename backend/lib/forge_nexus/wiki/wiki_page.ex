defmodule ForgeNexus.Wiki.WikiPage do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "wiki_pages" do
    field :title, :string
    field :slug, :string
    field :body, :string
    field :body_html, :string
    field :edit_permission, :string, default: "members"
    field :allowed_group_ids, :map, default: %{}
    field :is_published, :boolean, default: false
    field :is_locked, :boolean, default: false
    field :view_count, :integer, default: 0

    belongs_to :category, ForgeNexus.Wiki.WikiCategory
    belongs_to :created_by, ForgeNexus.Accounts.User
    belongs_to :last_edited_by, ForgeNexus.Accounts.User
    belongs_to :source_thread, ForgeNexus.Forums.Thread
    has_many :revisions, ForgeNexus.Wiki.WikiRevision, foreign_key: :page_id

    timestamps(type: :utc_datetime)
  end

  def changeset(struct, attrs) do
    struct
    |> cast(attrs, [
      :title,
      :slug,
      :body,
      :body_html,
      :edit_permission,
      :allowed_group_ids,
      :is_published,
      :is_locked,
      :view_count,
      :category_id,
      :created_by_id,
      :last_edited_by_id,
      :source_thread_id
    ])
    |> validate_required([:title, :slug, :body, :created_by_id])
    |> unique_constraint(:slug)
  end
end
