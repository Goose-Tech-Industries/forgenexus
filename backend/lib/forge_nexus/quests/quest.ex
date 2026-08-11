defmodule ForgeNexus.Quests.Quest do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "quests" do
    field :name, :string
    field :description, :string
    field :icon, :string
    field :quest_type, :string, default: "standard"
    field :steps, {:array, :map}, default: []
    field :rewards, :map, default: %{}
    field :is_daily, :boolean, default: false
    field :is_repeatable, :boolean, default: false
    field :is_active, :boolean, default: true
    field :required_level, :integer, default: 0
    field :sort_order, :integer, default: 0

    timestamps()
  end

  def changeset(quest, attrs) do
    quest
    |> cast(attrs, [
      :name,
      :description,
      :icon,
      :quest_type,
      :steps,
      :rewards,
      :is_daily,
      :is_repeatable,
      :is_active,
      :required_level,
      :sort_order
    ])
    |> validate_required([:name, :steps])
    |> validate_inclusion(:quest_type, ~w(standard daily weekly chain))
  end
end
