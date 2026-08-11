defmodule ForgeNexus.Billing do
  @moduledoc """
  Stripe billing for community SaaS subscriptions.

  Single source of truth for:
    * Plan → Stripe Price ID lookup (set via STRIPE_PRICE_* env vars)
    * Stripe Checkout Session creation
    * Webhook event processing (idempotent — uses StripeWebhookEvent table)
    * Community plan/status mutation in response to webhook events

  See project_forgenexus_revenue.md for the v3 revenue ladder.
  """

  import Ecto.Query
  require Logger

  alias ForgeNexus.Repo
  alias ForgeNexus.Communities.Community
  alias ForgeNexus.Billing.{CommunitySubscription, StripeWebhookEvent}

  @flat_price_plans ~w(forum community creator platform enterprise)
  @plans @flat_price_plans ++ ["houses"]

  @doc """
  Returns `{plan, %{name, monthly_cents, stripe_price_id}}` tuples for the
  active paid plans. Stripe Price IDs come from env (set per environment so
  test mode stays separate).
  """
  def plan_catalog do
    [
      {"forum",
       %{name: "Forum", monthly_cents: 1900, price_id: System.get_env("STRIPE_PRICE_FORUM")}},
      {"community",
       %{
         name: "Community",
         monthly_cents: 3900,
         price_id: System.get_env("STRIPE_PRICE_COMMUNITY")
       }},
      {"creator",
       %{name: "Creator", monthly_cents: 7900, price_id: System.get_env("STRIPE_PRICE_CREATOR")}},
      {"platform",
       %{
         name: "Platform",
         monthly_cents: 22500,
         price_id: System.get_env("STRIPE_PRICE_PLATFORM")
       }},
      {"enterprise",
       %{
         name: "Enterprise",
         monthly_cents: 35000,
         price_id: System.get_env("STRIPE_PRICE_ENTERPRISE")
       }}
    ]
  end

  def price_id_for(plan) when plan in @plans do
    plan_catalog() |> Enum.find_value(fn {p, info} -> if p == plan, do: info.price_id end)
  end

  def price_id_for(_), do: nil

  @doc """
  Houses Stripe Price IDs. Unlike the flat-price plans, Houses is variable:
  a flat base price (founder slot) plus a per-additional-creator price billed
  by quantity. Both must be set via env for Houses checkout to work — same
  "unset env var = not configured yet" pattern as the other 5 tiers, not
  wired up to a real Stripe account yet.
  """
  def houses_price_ids do
    %{
      base: System.get_env("STRIPE_PRICE_HOUSES_BASE"),
      per_creator: System.get_env("STRIPE_PRICE_HOUSES_PER_CREATOR")
    }
  end

  @doc """
  Creates a Stripe Checkout Session for the given community + plan.
  Returns `{:ok, %{url: ..., session_id: ...}}` on success.
  """
  def create_checkout_session(%Community{} = community, plan) when plan in @flat_price_plans do
    with {:ok, price_id} <- fetch_price_id(plan),
         {:ok, customer_id} <- ensure_customer(community),
         {:ok, session} <-
           start_checkout(community, plan, [%{price: price_id, quantity: 1}], customer_id) do
      {:ok, %{url: session.url, session_id: session.id}}
    end
  end

  def create_checkout_session(%Community{} = community, "houses") do
    with {:ok, line_items} <- fetch_houses_line_items(community),
         {:ok, customer_id} <- ensure_customer(community),
         {:ok, session} <- start_checkout(community, "houses", line_items, customer_id) do
      {:ok, %{url: session.url, session_id: session.id}}
    end
  end

  def create_checkout_session(_, _), do: {:error, :invalid_plan}

  defp fetch_price_id(plan) do
    case price_id_for(plan) do
      nil -> {:error, {:price_not_configured, plan}}
      price_id -> {:ok, price_id}
    end
  end

  # Base line item (qty 1) plus a per-creator add-on line item, quantity =
  # current member count minus the founder. member_count is the same
  # incrementally-maintained counter join_community/leave_community update,
  # so this reflects creators actually enrolled today, not what the founder
  # claimed at signup time.
  defp fetch_houses_line_items(%Community{} = community) do
    case houses_price_ids() do
      %{base: base, per_creator: per_creator}
      when is_binary(base) and base != "" and is_binary(per_creator) and per_creator != "" ->
        extra_creators = max((community.member_count || 1) - 1, 0)

        line_items =
          [%{price: base, quantity: 1}] ++
            if extra_creators > 0, do: [%{price: per_creator, quantity: extra_creators}], else: []

        {:ok, line_items}

      _ ->
        {:error, {:price_not_configured, "houses"}}
    end
  end

  defp ensure_customer(%Community{stripe_customer_id: id})
       when is_binary(id) and id != "" do
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
        Logger.error("[Billing] Stripe.Customer.create failed: #{inspect(reason)}")
        {:error, :stripe_error}
    end
  end

  defp start_checkout(community, plan, line_items, customer_id) do
    cfg = Application.get_env(:forge_nexus, :stripe, [])

    Stripe.Checkout.Session.create(%{
      mode: "subscription",
      customer: customer_id,
      line_items: line_items,
      success_url: Keyword.fetch!(cfg, :success_url),
      cancel_url: Keyword.fetch!(cfg, :cancel_url),
      client_reference_id: community.id,
      subscription_data: %{
        metadata: %{community_id: community.id, plan: plan, slug: community.slug}
      },
      metadata: %{community_id: community.id, plan: plan}
    })
  end

  # ----------------------------------------------------------------------
  # Webhook processing
  # ----------------------------------------------------------------------

  @doc """
  Verifies the Stripe-Signature header and processes the event idempotently.
  Returns `:ok` whether the event was new, already-processed, or unhandled —
  Stripe just needs a 2xx.
  """
  def handle_webhook(payload, signature) when is_binary(payload) and is_binary(signature) do
    secret =
      Application.get_env(:forge_nexus, :stripe, [])
      |> Keyword.get(:webhook_secret)

    if is_nil(secret) or secret == "" do
      Logger.error("[Billing] STRIPE_WEBHOOK_SECRET not configured; rejecting webhook")
      {:error, :no_secret}
    else
      case Stripe.Webhook.construct_event(payload, signature, secret) do
        {:ok, event} -> process_event(event)
        {:error, reason} -> {:error, {:invalid_signature, reason}}
      end
    end
  end

  defp process_event(%{id: stripe_event_id, type: type} = event) do
    case Repo.insert(
           %StripeWebhookEvent{}
           |> StripeWebhookEvent.changeset(%{
             stripe_event_id: stripe_event_id,
             type: type,
             payload: stringify(event)
           })
         ) do
      {:ok, row} ->
        try do
          dispatch(event)

          row
          |> Ecto.Changeset.change(processed_at: DateTime.utc_now() |> DateTime.truncate(:second))
          |> Repo.update!()

          :ok
        rescue
          err ->
            Logger.error(
              "[Billing] webhook #{type} #{stripe_event_id} failed: #{Exception.message(err)}"
            )

            reraise err, __STACKTRACE__
        end

      {:error, %Ecto.Changeset{errors: [stripe_event_id: _]}} ->
        # Already processed — Stripe retried, we already did the work.
        :ok

      {:error, cs} ->
        Logger.error("[Billing] webhook insert failed: #{inspect(cs.errors)}")
        {:error, :persist_failed}
    end
  end

  defp dispatch(%{type: "checkout.session.completed", data: %{object: session}}) do
    # The subscription record will arrive via customer.subscription.created.
    # Here we just log and stash the customer_id on the community in case
    # we hadn't seen it yet (e.g. raw Stripe Checkout link).
    case Map.get(session, :client_reference_id) do
      nil ->
        :ok

      community_id ->
        from(c in Community, where: c.id == ^community_id)
        |> Repo.update_all(set: [stripe_customer_id: Map.get(session, :customer)])

        :ok
    end
  end

  defp dispatch(%{type: "customer.subscription." <> _, data: %{object: sub}}) do
    upsert_subscription(sub)
  end

  defp dispatch(%{type: "invoice.payment_failed", data: %{object: invoice}}) do
    case Map.get(invoice, :subscription) do
      nil ->
        :ok

      sub_id ->
        from(s in CommunitySubscription, where: s.stripe_subscription_id == ^sub_id)
        |> Repo.update_all(set: [status: "past_due"])

        if community_id = Map.get(invoice, :metadata, %{})["community_id"] do
          from(c in Community, where: c.id == ^community_id)
          |> Repo.update_all(set: [plan_status: "past_due"])
        end

        :ok
    end
  end

  defp dispatch(%{type: type}) do
    Logger.debug("[Billing] unhandled webhook type #{type}")
    :ok
  end

  defp upsert_subscription(sub) do
    metadata = Map.get(sub, :metadata, %{}) || %{}
    community_id = metadata["community_id"]
    plan = metadata["plan"] || infer_plan_from_price(sub)

    if community_id && plan in @plans do
      attrs = %{
        community_id: community_id,
        stripe_subscription_id: sub.id,
        stripe_customer_id: Map.get(sub, :customer),
        stripe_price_id:
          get_in(sub, [:items, :data]) |> List.wrap() |> List.first() |> get_in([:price, :id]),
        plan: plan,
        status: to_string(Map.get(sub, :status, "active")),
        current_period_start: epoch_to_dt(Map.get(sub, :current_period_start)),
        current_period_end: epoch_to_dt(Map.get(sub, :current_period_end)),
        cancel_at_period_end: !!Map.get(sub, :cancel_at_period_end),
        canceled_at: epoch_to_dt(Map.get(sub, :canceled_at)),
        metadata: stringify(metadata)
      }

      case Repo.get_by(CommunitySubscription, stripe_subscription_id: sub.id) do
        nil ->
          %CommunitySubscription{} |> CommunitySubscription.changeset(attrs) |> Repo.insert!()

        existing ->
          existing |> CommunitySubscription.changeset(attrs) |> Repo.update!()
      end

      sync_community_plan(community_id, plan, attrs)
      :ok
    else
      Logger.warning(
        "[Billing] subscription #{sub.id} missing community_id or invalid plan: #{inspect(metadata)}"
      )

      :ok
    end
  end

  defp sync_community_plan(community_id, plan, %{status: status} = attrs) do
    plan_status =
      case status do
        "active" -> "active"
        "trialing" -> "trialing"
        "past_due" -> "past_due"
        "canceled" -> "canceled"
        _ -> "inactive"
      end

    set_fields = [
      plan: plan,
      plan_status: plan_status,
      current_period_end: attrs.current_period_end,
      cancel_at: if(attrs.cancel_at_period_end, do: attrs.current_period_end, else: nil)
    ]

    from(c in Community, where: c.id == ^community_id)
    |> Repo.update_all(set: set_fields)
  end

  defp infer_plan_from_price(sub) do
    price_id =
      get_in(sub, [:items, :data]) |> List.wrap() |> List.first() |> get_in([:price, :id])

    plan_catalog()
    |> Enum.find_value(fn {plan, info} -> if info.price_id == price_id, do: plan end)
  end

  defp epoch_to_dt(nil), do: nil

  defp epoch_to_dt(unix) when is_integer(unix),
    do: DateTime.from_unix!(unix) |> DateTime.truncate(:second)

  # Stripe events are structs; persist as plain maps for the audit log.
  defp stringify(%_{} = struct), do: struct |> Map.from_struct() |> stringify()

  defp stringify(map) when is_map(map),
    do: Map.new(map, fn {k, v} -> {to_string(k), stringify(v)} end)

  defp stringify(list) when is_list(list), do: Enum.map(list, &stringify/1)
  defp stringify(other), do: other
end
