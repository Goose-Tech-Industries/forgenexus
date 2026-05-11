defmodule ForgeNexus.Subscriptions.SubscriptionTier do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "subscription_tiers" do
    field :name, :string
    field :slug, :string
    field :tier_level, :integer
    field :description, :string
    field :price_monthly, :decimal
    field :price_yearly, :decimal
    field :color, :string
    field :icon, :string
    field :is_active, :boolean, default: true

    # Perks
    field :custom_username_color, :boolean, default: false
    field :custom_username_effects, :boolean, default: false
    field :animated_avatar, :boolean, default: false
    field :custom_banner, :boolean, default: false
    field :larger_uploads, :boolean, default: false
    field :upload_limit_mb, :integer, default: 10
    field :extended_bio, :boolean, default: false
    field :bio_char_limit, :integer, default: 500
    field :profile_music, :boolean, default: false
    field :custom_emoji_slots, :integer, default: 0
    field :exclusive_frames, {:array, :string}, default: []
    field :badge_text, :string
    field :priority_support, :boolean, default: false

    has_many :subscriptions, ForgeNexus.Subscriptions.UserSubscription, foreign_key: :tier_id

    timestamps()
  end

  def changeset(tier, attrs) do
    tier
    |> cast(attrs, [
      :name, :slug, :tier_level, :description, :price_monthly, :price_yearly,
      :color, :icon, :is_active, :custom_username_color, :custom_username_effects,
      :animated_avatar, :custom_banner, :larger_uploads, :upload_limit_mb,
      :extended_bio, :bio_char_limit, :profile_music, :custom_emoji_slots,
      :exclusive_frames, :badge_text, :priority_support
    ])
    |> validate_required([:name, :slug, :tier_level])
    |> unique_constraint(:slug)
    |> unique_constraint(:tier_level)
    |> validate_number(:tier_level, greater_than: 0)
  end
end
