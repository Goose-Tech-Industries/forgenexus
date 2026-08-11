defmodule ForgeNexus.Signup do
  @moduledoc """
  Tier signup orchestrator. Bundles the three-step provisioning the marketing
  funnel needs into one transactional call:

    1. Create the User (Accounts.register_user)
    2. Create the Community tenant (Communities.create_community), with the
       requesting user as owner and `plan_status: "trialing"`.
    3. If Stripe is configured for the chosen plan, create a Checkout Session
       with a trial period and return its URL. If not, the community remains
       in `trialing` status with no Stripe sub — caller can finish billing
       setup later from the dashboard.

  This module does NOT modify the User or Community schemas; everything it
  needs already exists. It is a thin coordinator so the controller stays
  small and testable.
  """

  alias ForgeNexus.{Accounts, Billing, Communities, Repo}
  alias ForgeNexus.Communities.Community

  require Logger

  @paid_plans ~w(forum community creator platform enterprise)

  # Tier 1 (forum) opens with a longer free runway. Tier 2+ honors the
  # 14-day trial pattern from the marketing copy.
  @trial_days %{
    "forum" => 30,
    "community" => 14,
    "creator" => 14,
    "platform" => 14,
    "enterprise" => 14
  }

  @type signup_attrs :: %{
          required(:email) => String.t(),
          required(:password) => String.t(),
          required(:username) => String.t(),
          required(:community_slug) => String.t(),
          required(:community_name) => String.t(),
          required(:plan) => String.t(),
          optional(:registered_ip) => String.t()
        }

  @doc """
  Provision a new tier signup. Wraps user + community creation in a
  transaction so a failure on either leaves no orphan rows. Stripe
  checkout creation happens AFTER commit (third-party side-effect) so
  the DB transaction isn't held open across a network call.
  """
  @spec provision(signup_attrs) ::
          {:ok,
           %{
             user: map(),
             community: %Community{},
             checkout_url: String.t() | nil,
             stripe_status: atom()
           }}
          | {:error, atom() | Ecto.Changeset.t() | tuple()}
  def provision(%{plan: plan} = attrs) when plan in @paid_plans do
    Repo.transaction(fn ->
      with {:ok, user} <- create_user(attrs),
           {:ok, community} <- create_tenant(user, attrs) do
        # Owner becomes a member of their own community immediately.
        Communities.join_community(community.id, user.id, "owner")
        %{user: user, community: community}
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
    |> case do
      {:ok, %{user: user, community: community}} ->
        {checkout_url, stripe_status} = maybe_start_checkout(community, plan)

        {:ok,
         %{
           user: user,
           community: community,
           checkout_url: checkout_url,
           stripe_status: stripe_status
         }}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def provision(%{plan: _}), do: {:error, :invalid_plan}

  defp create_user(attrs) do
    user_attrs = %{
      "email" => String.downcase(attrs.email),
      "password" => attrs.password,
      "username" => attrs.username,
      "display_name" => attrs.username,
      "registered_ip" => Map.get(attrs, :registered_ip)
    }

    Accounts.register_user(user_attrs)
  end

  defp create_tenant(user, attrs) do
    trial_days = Map.get(@trial_days, attrs.plan, 14)
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    Communities.create_community(%{
      "name" => attrs.community_name,
      "slug" => attrs.community_slug,
      "subdomain" => attrs.community_slug,
      "owner_id" => user.id,
      "plan" => attrs.plan,
      "plan_status" => "trialing",
      "current_period_end" => DateTime.add(now, trial_days * 86400, :second)
    })
  end

  # Stripe is a third-party side-effect — runs outside the DB transaction.
  # Failure here doesn't roll back user/community: the trial is already
  # live, the owner can wire payment later.
  defp maybe_start_checkout(%Community{} = community, plan) do
    trial_days = Map.get(@trial_days, plan, 14)

    case Billing.price_id_for(plan) do
      nil ->
        {nil, :not_configured}

      _price_id ->
        case create_checkout_with_trial(community, plan, trial_days) do
          {:ok, %{url: url}} ->
            {url, :ok}

          {:error, reason} ->
            Logger.warning("[Signup] Stripe checkout deferred: #{inspect(reason)}")
            {nil, :stripe_error}
        end
    end
  end

  # Mirrors Billing.create_checkout_session/2 but injects a trial period.
  # Done here (not in Billing) so the existing upgrade flow keeps its
  # immediate-charge semantics.
  defp create_checkout_with_trial(%Community{} = community, plan, trial_days) do
    with {:ok, price_id} <- fetch_price_id(plan),
         {:ok, customer_id} <- ensure_customer(community) do
      cfg = Application.get_env(:forge_nexus, :stripe, [])

      Stripe.Checkout.Session.create(%{
        mode: "subscription",
        customer: customer_id,
        line_items: [%{price: price_id, quantity: 1}],
        success_url: Keyword.fetch!(cfg, :success_url),
        cancel_url: Keyword.fetch!(cfg, :cancel_url),
        client_reference_id: community.id,
        subscription_data: %{
          trial_period_days: trial_days,
          metadata: %{community_id: community.id, plan: plan, slug: community.slug}
        },
        metadata: %{community_id: community.id, plan: plan}
      })
      |> case do
        {:ok, session} -> {:ok, %{url: session.url, session_id: session.id}}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  defp fetch_price_id(plan) do
    case Billing.price_id_for(plan) do
      nil -> {:error, {:price_not_configured, plan}}
      price_id -> {:ok, price_id}
    end
  end

  defp ensure_customer(%Community{stripe_customer_id: id}) when is_binary(id) and id != "" do
    {:ok, id}
  end

  defp ensure_customer(%Community{} = community) do
    case Stripe.Customer.create(%{
           name: community.name,
           metadata: %{community_id: community.id, slug: community.slug}
         }) do
      {:ok, customer} ->
        community
        |> Ecto.Changeset.change(stripe_customer_id: customer.id)
        |> Repo.update!()

        {:ok, customer.id}

      {:error, reason} ->
        {:error, {:stripe_customer_failed, reason}}
    end
  end
end
