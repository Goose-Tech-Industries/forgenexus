defmodule ForgeNexus.Plugins.PluginPage do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "plugin_pages" do
    field :slug, :string
    field :title, :string
    field :description, :string
    field :template, :map, default: %{}
    field :is_published, :boolean, default: false
    field :nav_position, :integer
    field :nav_label, :string

    belongs_to :flow, ForgeNexus.Plugins.Flow

    timestamps()
  end

  def changeset(page, attrs) do
    page
    |> cast(attrs, [:flow_id, :slug, :title, :description, :template, :is_published, :nav_position, :nav_label])
    |> validate_required([:flow_id, :slug, :title])
    |> unique_constraint(:slug)
    |> foreign_key_constraint(:flow_id)
  end
end
