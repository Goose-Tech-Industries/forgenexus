defmodule ForgeNexus.Forums.Thread do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "threads" do
    field :title, :string
    field :slug, :string
    field :is_pinned, :boolean, default: false
    field :is_locked, :boolean, default: false
    field :is_hidden, :boolean, default: false
    field :is_approved, :boolean, default: true
    field :pin_position, :integer, default: 0
    field :view_count, :integer, default: 0
    field :reply_count, :integer, default: 0
    field :last_post_at, :utc_datetime
    field :prefix, :string
    field :tags, {:array, :string}, default: []

    field :auto_close_at, :utc_datetime
    field :auto_delete_at, :utc_datetime
    field :thumbnail_url, :string
    field :scheduled_at, :utc_datetime
    field :status, :string, default: "published"
    field :is_solved, :boolean, default: false
    field :solved_post_id, :binary_id
    field :is_private, :boolean, default: false

    belongs_to :community, ForgeNexus.Communities.Community
    belongs_to :forum, ForgeNexus.Forums.Forum
    belongs_to :user, ForgeNexus.Accounts.User
    belongs_to :last_post_user, ForgeNexus.Accounts.User
    belongs_to :moved_from_forum, ForgeNexus.Forums.Forum
    belongs_to :merged_into, __MODULE__
    has_many :posts, ForgeNexus.Forums.Post
    has_one :poll, ForgeNexus.Forums.Poll

    timestamps()
  end

  def changeset(thread, attrs) do
    thread
    |> cast(attrs, [:title, :slug, :is_pinned, :is_locked, :prefix, :tags, :forum_id, :user_id, :scheduled_at, :status])
    |> validate_required([:title, :forum_id, :user_id])
    |> validate_length(:title, min: 3, max: 200)
    |> generate_slug()
    |> foreign_key_constraint(:forum_id)
    |> validate_inclusion(:status, ["published", "scheduled", "draft"])
    |> maybe_set_scheduled_status()
    |> foreign_key_constraint(:user_id)
  end

  def mod_changeset(thread, attrs) do
    thread
    |> cast(attrs, [:is_pinned, :is_locked, :is_hidden, :is_approved, :forum_id, :moved_from_forum_id, :merged_into_id, :auto_close_at, :auto_delete_at, :status, :scheduled_at])
  end

  defp maybe_set_scheduled_status(changeset) do
    case get_change(changeset, :scheduled_at) do
      nil -> changeset
      scheduled_at ->
        now = DateTime.utc_now()
        if DateTime.compare(scheduled_at, now) == :gt do
          changeset
          |> put_change(:status, "scheduled")
          |> put_change(:is_hidden, true)
        else
          changeset
        end
    end
  end

  defp generate_slug(changeset) do
    case get_change(changeset, :title) do
      nil -> changeset
      title ->
        slug = get_change(changeset, :slug) || Slug.slugify(title)
        put_change(changeset, :slug, slug)
    end
  end
end
