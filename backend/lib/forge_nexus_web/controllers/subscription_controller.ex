defmodule ForgeNexusWeb.SubscriptionController do
  use ForgeNexusWeb, :controller

  alias ForgeNexus.Subscriptions

  # GET /api/subscriptions/tiers — public, list all active tiers
  def tiers(conn, _params) do
    tiers = Subscriptions.list_tiers()
    conn |> json(%{tiers: Enum.map(tiers, &tier_json/1)})
  end

  # GET /api/subscriptions/my — authenticated, get current user subscription
  def my_subscription(conn, _params) do
    user = Guardian.Plug.current_resource(conn)

    case Subscriptions.get_user_subscription(user) do
      nil ->
        conn |> json(%{subscription: nil})

      subscription ->
        conn |> json(%{subscription: subscription_json(subscription)})
    end
  end

  # POST /api/subscriptions — authenticated, subscribe to a tier
  def create(conn, %{"tier_id" => tier_id}) do
    user = Guardian.Plug.current_resource(conn)

    case Subscriptions.get_tier(tier_id) do
      nil ->
        conn |> put_status(:not_found) |> json(%{error: "Tier not found"})

      tier ->
        case Subscriptions.subscribe_user(user, tier) do
          {:ok, subscription} ->
            subscription = ForgeNexus.Repo.preload(subscription, :tier)

            conn
            |> put_status(:created)
            |> json(%{subscription: subscription_json(subscription)})

          {:error, changeset} ->
            conn
            |> put_status(:unprocessable_entity)
            |> json(%{errors: format_errors(changeset)})
        end
    end
  end

  # DELETE /api/subscriptions — authenticated, cancel subscription
  def cancel(conn, _params) do
    user = Guardian.Plug.current_resource(conn)

    case Subscriptions.get_user_subscription(user) do
      nil ->
        conn |> put_status(:not_found) |> json(%{error: "No active subscription"})

      subscription ->
        case Subscriptions.cancel_subscription(subscription) do
          {:ok, cancelled} ->
            cancelled = ForgeNexus.Repo.preload(cancelled, :tier)
            conn |> json(%{subscription: subscription_json(cancelled)})

          {:error, changeset} ->
            conn
            |> put_status(:unprocessable_entity)
            |> json(%{errors: format_errors(changeset)})
        end
    end
  end

  defp tier_json(tier) do
    %{
      id: tier.id,
      name: tier.name,
      slug: tier.slug,
      tier_level: tier.tier_level,
      description: tier.description,
      price_monthly: tier.price_monthly,
      price_yearly: tier.price_yearly,
      color: tier.color,
      icon: tier.icon,
      is_active: tier.is_active,
      badge_text: tier.badge_text,
      custom_username_color: tier.custom_username_color,
      custom_username_effects: tier.custom_username_effects,
      animated_avatar: tier.animated_avatar,
      custom_banner: tier.custom_banner,
      larger_uploads: tier.larger_uploads,
      upload_limit_mb: tier.upload_limit_mb,
      extended_bio: tier.extended_bio,
      bio_char_limit: tier.bio_char_limit,
      profile_music: tier.profile_music,
      custom_emoji_slots: tier.custom_emoji_slots,
      exclusive_frames: tier.exclusive_frames,
      priority_support: tier.priority_support
    }
  end

  defp subscription_json(subscription) do
    %{
      id: subscription.id,
      status: subscription.status,
      started_at: subscription.started_at,
      expires_at: subscription.expires_at,
      cancelled_at: subscription.cancelled_at,
      payment_method: subscription.payment_method,
      tier: tier_json(subscription.tier)
    }
  end

  defp format_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
