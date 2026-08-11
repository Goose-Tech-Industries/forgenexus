defmodule ForgeNexus.Spaces.CommunityMap do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "community_maps" do
    field :name, :string
    field :slug, :string
    field :description, :string
    field :is_default, :boolean, default: false
    field :background_image_url, :string
    field :width, :integer
    field :height, :integer
    field :is_active, :boolean, default: true
    field :config, :map, default: %{}

    has_many :rooms, ForgeNexus.Spaces.MapRoom, foreign_key: :map_id

    timestamps(type: :utc_datetime)
  end

  def changeset(struct, attrs) do
    struct
    |> cast(attrs, [
      :name,
      :slug,
      :description,
      :is_default,
      :background_image_url,
      :width,
      :height,
      :is_active,
      :config
    ])
    |> validate_required([:name, :slug, :width, :height])
    |> unique_constraint(:slug)
  end
end
