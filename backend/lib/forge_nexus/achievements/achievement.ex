defmodule ForgeNexus.Achievements.Achievement do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "achievements" do
    field :name, :string
    field :slug, :string
    field :description, :string
    field :icon, :string
    field :category, :string
    field :points, :integer, default: 0
    field :badge_id, :binary_id
    field :criteria, :map, default: %{}
    field :is_hidden, :boolean, default: false
    field :is_active, :boolean, default: true
    field :sort_order, :integer, default: 0

    timestamps()
  end

  def changeset(achievement, attrs) do
    achievement
    |> cast(attrs, [
      :name,
      :slug,
      :description,
      :icon,
      :category,
      :points,
      :badge_id,
      :criteria,
      :is_hidden,
      :is_active,
      :sort_order
    ])
    |> validate_required([:name, :slug, :criteria])
    |> unique_constraint(:slug)
  end
end
