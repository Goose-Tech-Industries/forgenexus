defmodule ForgeNexus.Social.GiftTier do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @tiers ~w(micro small medium large legendary)
  @animations ~w(float_up burst explode rain screen_fill pulse shake)

  schema "gift_tiers" do
    field :name, :string
    field :emoji, :string
    field :tier, :string
    field :cost, :integer
    field :animation_type, :string, default: "float_up"
    field :animation_duration_ms, :integer, default: 3000
    field :color, :string
    field :sound_url, :string
    field :is_active, :boolean, default: true
    field :position, :integer, default: 0

    belongs_to :community, ForgeNexus.Communities.Community

    timestamps()
  end

  def changeset(gift, attrs) do
    gift
    |> cast(attrs, [:community_id, :name, :emoji, :tier, :cost, :animation_type,
                     :animation_duration_ms, :color, :sound_url, :is_active, :position])
    |> validate_required([:name, :tier, :cost])
    |> validate_inclusion(:tier, @tiers)
    |> validate_inclusion(:animation_type, @animations)
    |> validate_number(:cost, greater_than: 0)
  end

  def tiers, do: @tiers

  def default_gifts do
    [
      %{name: "Heart", emoji: "❤️", tier: "micro", cost: 1, animation_type: "float_up", animation_duration_ms: 2000},
      %{name: "Thumbs Up", emoji: "👍", tier: "micro", cost: 5, animation_type: "float_up", animation_duration_ms: 2000},
      %{name: "Fire", emoji: "🔥", tier: "small", cost: 25, animation_type: "burst", animation_duration_ms: 3000},
      %{name: "Star", emoji: "⭐", tier: "small", cost: 50, animation_type: "burst", animation_duration_ms: 3000},
      %{name: "Diamond", emoji: "💎", tier: "medium", cost: 250, animation_type: "explode", animation_duration_ms: 4000},
      %{name: "Crown", emoji: "👑", tier: "medium", cost: 500, animation_type: "explode", animation_duration_ms: 4000},
      %{name: "Dragon", emoji: "🐉", tier: "large", cost: 2500, animation_type: "screen_fill", animation_duration_ms: 5000},
      %{name: "Universe", emoji: "🌌", tier: "legendary", cost: 10000, animation_type: "screen_fill", animation_duration_ms: 8000}
    ]
  end
end
