defmodule ForgeNexusWeb.BillingController do
  @moduledoc """
  Community SaaS subscription endpoints. Distinct from SubscriptionController,
  which handles creator-level subs (Twitch-style $4.99/$9.99/$24.99 tiers).
  This one is for the community plan ladder ($19 Forum → $350 Enterprise).
  """
  use ForgeNexusWeb, :controller

  alias ForgeNexus.{Billing, Houses, Repo}
  alias ForgeNexus.Communities.Community

  # GET /api/billing/plans — public catalog
  def plans(conn, _params) do
    plans =
      Billing.plan_catalog()
      |> Enum.map(fn {key, info} ->
        %{
          plan: key,
          name: info.name,
          monthly_cents: info.monthly_cents,
          monthly_price: format_price(info.monthly_cents),
          available: not is_nil(info.price_id) and info.price_id != ""
        }
      end)

    json(conn, %{plans: plans ++ [houses_catalog_entry()]})
  end

  defp houses_catalog_entry do
    base_cents = Houses.monthly_cents(0)
    per_creator_cents = Houses.monthly_cents(1) - base_cents
    %{base: base_price_id, per_creator: per_creator_price_id} = Billing.houses_price_ids()

    %{
      plan: "houses",
      name: "Houses",
      monthly_cents: base_cents,
      monthly_price: "#{format_price(base_cents)}+",
      per_creator_cents: per_creator_cents,
      per_creator_price: format_price(per_creator_cents),
      available:
        not is_nil(base_price_id) and base_price_id != "" and
          not is_nil(per_creator_price_id) and per_creator_price_id != ""
    }
  end

  # POST /api/billing/communities/:community_id/checkout
  # body: %{plan: "forum"|"community"|"creator"|"platform"|"enterprise"}
  def create_checkout(conn, %{"community_id" => community_id, "plan" => plan}) do
    user = Guardian.Plug.current_resource(conn)

    with {:ok, community} <- fetch_community(community_id),
         :ok <- ensure_owner(community, user),
         {:ok, %{url: url, session_id: session_id}} <-
           Billing.create_checkout_session(community, plan) do
      json(conn, %{checkout_url: url, session_id: session_id})
    else
      {:error, :not_found} ->
        conn |> put_status(:not_found) |> json(%{error: "Community not found"})

      {:error, :forbidden} ->
        conn
        |> put_status(:forbidden)
        |> json(%{error: "Only the community owner can manage billing"})

      {:error, :invalid_plan} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: "Invalid plan"})

      {:error, {:price_not_configured, plan}} ->
        conn
        |> put_status(:service_unavailable)
        |> json(%{error: "Plan #{plan} not configured yet"})

      {:error, reason} ->
        require Logger
        Logger.error("[BillingController] checkout failed: #{inspect(reason)}")
        conn |> put_status(:internal_server_error) |> json(%{error: "Stripe error — try again"})
    end
  end

  # GET /api/billing/communities/:community_id/subscription
  def show(conn, %{"community_id" => community_id}) do
    user = Guardian.Plug.current_resource(conn)

    with {:ok, community} <- fetch_community(community_id),
         :ok <- ensure_owner(community, user) do
      json(conn, %{
        plan: community.plan,
        plan_status: community.plan_status,
        current_period_end: community.current_period_end,
        cancel_at: community.cancel_at,
        stripe_customer_id: community.stripe_customer_id
      })
    else
      {:error, :not_found} -> conn |> put_status(:not_found) |> json(%{error: "Not found"})
      {:error, :forbidden} -> conn |> put_status(:forbidden) |> json(%{error: "Owner only"})
    end
  end

  defp fetch_community(id) do
    case Repo.get(Community, id) do
      nil -> {:error, :not_found}
      community -> {:ok, community}
    end
  end

  defp ensure_owner(%Community{owner_id: owner_id}, %{id: user_id}) when owner_id == user_id,
    do: :ok

  defp ensure_owner(_, _), do: {:error, :forbidden}

  defp format_price(cents) when is_integer(cents) do
    dollars = div(cents, 100)
    rem = rem(cents, 100)

    if rem == 0,
      do: "$#{dollars}",
      else: :io_lib.format("$~B.~2..0B", [dollars, rem]) |> IO.iodata_to_binary()
  end
end
