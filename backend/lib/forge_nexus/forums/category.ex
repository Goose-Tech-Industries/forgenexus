defmodule ForgeNexus.Forums.Category do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "categories" do
    field :name, :string
    field :slug, :string
    field :description, :string
    field :icon, :string
    field :color, :string
    field :position, :integer, default: 0
    field :is_visible, :boolean, default: true

    belongs_to :community, ForgeNexus.Communities.Community
    belongs_to :parent, __MODULE__
    has_many :children, __MODULE__, foreign_key: :parent_id
    has_many :forums, ForgeNexus.Forums.Forum

    timestamps()
  end

  def changeset(category, attrs) do
    category
    |> cast(attrs, [:name, :slug, :description, :icon, :color, :position, :is_visible, :parent_id])
    |> validate_required([:name])
    |> generate_slug()
    |> unique_constraint(:slug)
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
