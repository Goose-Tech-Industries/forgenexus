defmodule ForgeNexus.Subscriptions do
  @moduledoc """
  The Subscriptions context — subscription tiers and user subscriptions.
  """
  import Ecto.Query
  alias ForgeNexus.Repo
  alias ForgeNexus.Subscriptions.{SubscriptionTier, UserSubscription}

  # --- Tiers ---

  def list_tiers do
    SubscriptionTier
    |> where([t], t.is_active == true)
    |> order_by(:tier_level)
    |> Repo.all()
  end

  def list_all_tiers do
    SubscriptionTier
    |> order_by(:tier_level)
    |> Repo.all()
  end

  def get_tier(id), do: Repo.get(SubscriptionTier, id)

  def get_tier!(id), do: Repo.get!(SubscriptionTier, id)

  def get_tier_by_slug(slug), do: Repo.get_by(SubscriptionTier, slug: slug)

  def create_tier(attrs) do
    %SubscriptionTier{}
    |> SubscriptionTier.changeset(attrs)
    |> Repo.insert()
  end

  def update_tier(%SubscriptionTier{} = tier, attrs) do
    tier
    |> SubscriptionTier.changeset(attrs)
    |> Repo.update()
  end

  def delete_tier(id) do
    case Repo.get(SubscriptionTier, id) do
      nil -> {:error, :not_found}
      tier -> Repo.delete(tier)
    end
  end

  # --- User Subscriptions ---

  def subscribe_user(user, tier, attrs \\ %{}) do
    # Cancel any existing active subscription first
    case get_user_subscription(user) do
      nil -> :ok
      existing -> cancel_subscription(existing)
    end

    %UserSubscription{}
    |> UserSubscription.changeset(
      Map.merge(attrs, %{
        user_id: user.id,
        tier_id: tier.id,
        status: "active",
        started_at: DateTime.utc_now() |> DateTime.truncate(:second)
      })
    )
    |> Repo.insert()
  end

  def cancel_subscription(%UserSubscription{} = subscription) do
    subscription
    |> UserSubscription.changeset(%{
      status: "cancelled",
      cancelled_at: DateTime.utc_now() |> DateTime.truncate(:second)
    })
    |> Repo.update()
  end

  def get_user_subscription(user) do
    UserSubscription
    |> where([s], s.user_id == ^user.id and s.status == "active")
    |> preload(:tier)
    |> Repo.one()
  end

  def user_has_perk?(user_id, perk_atom) do
    sub =
      UserSubscription
      |> where([s], s.user_id == ^user_id and s.status == "active")
      |> preload(:tier)
      |> Repo.one()

    case sub do
      nil -> false
      %{tier: tier} -> Map.get(tier, perk_atom, false)
    end
  end

  # --- Seed Default Tiers ---

  def seed_default_tiers do
    tiers = [
      %{
        name: "Ember",
        slug: "ember",
        tier_level: 1,
        description: "Support the community and unlock basic customization perks.",
        price_monthly: Decimal.new("4.99"),
        price_yearly: Decimal.new("49.99"),
        color: "#ff6b35",
        icon: "flame",
        badge_text: "EMBER",
        custom_username_color: true,
        custom_username_effects: false,
        animated_avatar: false,
        custom_banner: false,
        larger_uploads: false,
        upload_limit_mb: 25,
        extended_bio: false,
        bio_char_limit: 500,
        profile_music: false,
        custom_emoji_slots: 0,
        exclusive_frames: [],
        priority_support: false
      },
      %{
        name: "Ember+",
        slug: "ember-plus",
        tier_level: 2,
        description: "Enhanced perks with animated avatars, custom banners, and more.",
        price_monthly: Decimal.new("9.99"),
        price_yearly: Decimal.new("99.99"),
        color: "#ff9500",
        icon: "fire",
        badge_text: "EMBER+",
        custom_username_color: true,
        custom_username_effects: true,
        animated_avatar: true,
        custom_banner: true,
        larger_uploads: true,
        upload_limit_mb: 50,
        extended_bio: true,
        bio_char_limit: 2000,
        profile_music: false,
        custom_emoji_slots: 5,
        exclusive_frames: [],
        priority_support: false
      },
      %{
        name: "Ascended",
        slug: "ascended",
        tier_level: 3,
        description: "The ultimate tier. Profile music, exclusive frames, and priority support.",
        price_monthly: Decimal.new("19.99"),
        price_yearly: Decimal.new("199.99"),
        color: "#9b59b6",
        icon: "crown",
        badge_text: "ASCENDED",
        custom_username_color: true,
        custom_username_effects: true,
        animated_avatar: true,
        custom_banner: true,
        larger_uploads: true,
        upload_limit_mb: 100,
        extended_bio: true,
        bio_char_limit: 5000,
        profile_music: true,
        custom_emoji_slots: 25,
        exclusive_frames: ["legendary", "divine", "cosmic"],
        priority_support: true
      }
    ]

    Enum.each(tiers, fn tier_attrs ->
      case get_tier_by_slug(tier_attrs.slug) do
        nil -> create_tier(tier_attrs)
        _existing -> :ok
      end
    end)

    :ok
  end
end
