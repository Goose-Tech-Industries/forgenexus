defmodule ForgeNexusWeb.AdminSubscriptionTierController do
  use ForgeNexusWeb, :controller

  alias ForgeNexus.Subscriptions

  # GET /api/admin/subscription-tiers
  def index(conn, _params) do
    tiers = Subscriptions.list_all_tiers()
    conn |> json(%{tiers: Enum.map(tiers, &tier_json/1)})
  end

  # POST /api/admin/subscription-tiers
  def create(conn, %{"tier" => tier_params}) do
    case Subscriptions.create_tier(tier_params) do
      {:ok, tier} ->
        user = Guardian.Plug.current_resource(conn)
        ForgeNexus.Admin.log_admin_action(user.id, %{
          action: "tier_created", category: "subscriptions",
          target_type: "subscription_tier", target_id: tier.id,
          description: "Created subscription tier: #{tier.name}"
        })

        conn
        |> put_status(:created)
        |> json(%{tier: tier_json(tier)})

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: format_errors(changeset)})
    end
  end

  # PUT /api/admin/subscription-tiers/:id
  def update(conn, %{"id" => id, "tier" => tier_params}) do
    case Subscriptions.get_tier(id) do
      nil ->
        conn |> put_status(:not_found) |> json(%{error: "Tier not found"})

      tier ->
        case Subscriptions.update_tier(tier, tier_params) do
          {:ok, updated} ->
            user = Guardian.Plug.current_resource(conn)
            ForgeNexus.Admin.log_admin_action(user.id, %{
              action: "tier_updated", category: "subscriptions",
              target_type: "subscription_tier", target_id: updated.id,
              description: "Updated subscription tier: #{updated.name}"
            })

            conn |> json(%{tier: tier_json(updated)})

          {:error, changeset} ->
            conn
            |> put_status(:unprocessable_entity)
            |> json(%{errors: format_errors(changeset)})
        end
    end
  end

  # DELETE /api/admin/subscription-tiers/:id
  def delete(conn, %{"id" => id}) do
    case Subscriptions.delete_tier(id) do
      {:ok, tier} ->
        user = Guardian.Plug.current_resource(conn)
        ForgeNexus.Admin.log_admin_action(user.id, %{
          action: "tier_deleted", category: "subscriptions",
          target_type: "subscription_tier", target_id: tier.id,
          description: "Deleted subscription tier: #{tier.name}"
        })

        conn |> json(%{ok: true})

      {:error, :not_found} ->
        conn |> put_status(:not_found) |> json(%{error: "Tier not found"})

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: format_errors(changeset)})
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
      priority_support: tier.priority_support,
      inserted_at: tier.inserted_at,
      updated_at: tier.updated_at
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
