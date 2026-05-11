defmodule ForgeNexus.Forums.Forum do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "forums" do
    field :name, :string
    field :slug, :string
    field :description, :string
    field :icon, :string
    field :color, :string
    field :position, :integer, default: 0
    field :is_visible, :boolean, default: true
    field :is_locked, :boolean, default: false
    field :thread_count, :integer, default: 0
    field :post_count, :integer, default: 0
    field :last_post_at, :utc_datetime
    field :last_thread_id, :binary_id
    field :permissions, :map, default: %{}
    field :rules, :string
    field :is_private, :boolean, default: false
    field :require_post_approval, :boolean, default: false
    field :allow_thread_ratings, :boolean, default: false
    field :min_post_length, :integer, default: 1

    belongs_to :community, ForgeNexus.Communities.Community
    belongs_to :category, ForgeNexus.Forums.Category
    belongs_to :parent, __MODULE__
    belongs_to :last_post_user, ForgeNexus.Accounts.User
    has_many :children, __MODULE__, foreign_key: :parent_id
    has_many :threads, ForgeNexus.Forums.Thread

    timestamps()
  end

  def changeset(forum, attrs) do
    forum
    |> cast(attrs, [:name, :slug, :description, :icon, :color, :position, :is_visible, :is_locked, :category_id, :parent_id, :permissions])
    |> validate_required([:name, :category_id])
    |> generate_slug()
    |> unique_constraint(:slug)
    |> foreign_key_constraint(:category_id)
  end

  defp generate_slug(changeset) do
    case get_change(changeset, :name) do
      nil -> changeset
      name ->
        slug = get_change(changeset, :slug) || Slug.slugify(name)
        put_change(changeset, :slug, slug)
    end
  end
end
