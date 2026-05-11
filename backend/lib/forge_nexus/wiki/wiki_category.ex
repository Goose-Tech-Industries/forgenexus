defmodule ForgeNexus.Wiki.WikiCategory do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "wiki_categories" do
    field :name, :string
    field :slug, :string
    field :description, :string
    field :position, :integer, default: 0
    field :icon, :string
    field :is_visible, :boolean, default: true

    belongs_to :parent, __MODULE__
    has_many :children, __MODULE__, foreign_key: :parent_id
    has_many :pages, ForgeNexus.Wiki.WikiPage, foreign_key: :category_id

    timestamps(type: :utc_datetime)
  end

  def changeset(struct, attrs) do
    struct
    |> cast(attrs, [:name, :slug, :description, :position, :icon, :is_visible, :parent_id])
    |> validate_required([:name, :slug])
    |> unique_constraint(:slug)
  end
end
