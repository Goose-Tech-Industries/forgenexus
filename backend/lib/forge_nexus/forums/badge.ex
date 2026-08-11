defmodule ForgeNexus.Forums.Badge do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "badges" do
    field :name, :string
    field :description, :string
    field :icon_url, :string
    field :icon_emoji, :string
    field :color, :string
    field :category, :string, default: "achievement"
    field :is_auto, :boolean, default: false
    field :auto_criteria, :map
    field :position, :integer, default: 0
    field :is_active, :boolean, default: true

    has_many :user_badges, ForgeNexus.Forums.UserBadge

    timestamps()
  end

  def changeset(badge, attrs) do
    badge
    |> cast(attrs, [
      :name,
      :description,
      :icon_url,
      :icon_emoji,
      :color,
      :category,
      :is_auto,
      :auto_criteria,
      :position,
      :is_active
    ])
    |> validate_required([:name])
    |> validate_inclusion(:category, ["achievement", "milestone", "admin_granted", "event"])
    |> unique_constraint(:name)
  end
end
