defmodule ForgeNexus.BillingWebhookTest do
  use ForgeNexus.DataCase, async: false

  alias ForgeNexus.Billing
  alias ForgeNexus.Billing.{CommunitySubscription, StripeWebhookEvent}
  alias ForgeNexus.Communities.Community

  # async: false -- tests mutate the :forge_nexus, :stripe application env
  # (webhook_secret) for the duration of the run.

  @secret "whsec_test_secret_123"

  setup do
    Application.put_env(:forge_nexus, :stripe, webhook_secret: @secret)
    on_exit(fn -> Application.delete_env(:forge_nexus, :stripe) end)
    :ok
  end

  describe "handle_webhook/2 — signature verification" do
    test "rejects when no webhook secret is configured" do
      Application.delete_env(:forge_nexus, :stripe)

      payload =
        event_json("evt_no_secret", "checkout.session.completed", %{
          "object" => "checkout.session"
        })

      sig = sign(payload, @secret)

      assert Billing.handle_webhook(payload, sig) == {:error, :no_secret}
    end

    test "rejects a signature that doesn't match the payload" do
      payload =
        event_json("evt_bad_sig", "checkout.session.completed", %{"object" => "checkout.session"})

      assert {:error, {:invalid_signature, _}} =
               Billing.handle_webhook(payload, "t=1700000000,v1=0000000000000000")
    end

    test "accepts a correctly signed payload" do
      payload = event_json("evt_good_sig", "some.unhandled.type", %{"object" => "unhandled"})
      sig = sign(payload, @secret)

      assert Billing.handle_webhook(payload, sig) == :ok
    end
  end

  describe "handle_webhook/2 — idempotency" do
    test "the same event id is only ever persisted once, even if delivered twice" do
      community = insert_community!(%{})

      payload =
        event_json("evt_dup_1", "checkout.session.completed", %{
          "object" => "checkout.session",
          "client_reference_id" => community.id,
          "customer" => "cus_dup_test"
        })

      sig = sign(payload, @secret)

      assert Billing.handle_webhook(payload, sig) == :ok
      assert Billing.handle_webhook(payload, sig) == :ok

      assert Repo.aggregate(
               from(e in StripeWebhookEvent, where: e.stripe_event_id == "evt_dup_1"),
               :count
             ) == 1
    end
  end

  describe "checkout.session.completed" do
    test "stashes the Stripe customer id on the community via client_reference_id" do
      community = insert_community!(%{})

      payload =
        event_json("evt_checkout_1", "checkout.session.completed", %{
          "object" => "checkout.session",
          "client_reference_id" => community.id,
          "customer" => "cus_abc123"
        })

      assert Billing.handle_webhook(payload, sign(payload, @secret)) == :ok
      assert Repo.get!(Community, community.id).stripe_customer_id == "cus_abc123"
    end

    test "no-ops without error when client_reference_id is missing" do
      payload =
        event_json("evt_checkout_2", "checkout.session.completed", %{
          "object" => "checkout.session",
          "customer" => "cus_orphan"
        })

      assert Billing.handle_webhook(payload, sign(payload, @secret)) == :ok
    end
  end

  describe "customer.subscription.* — the bug this whole file exists to catch" do
    test "creates a CommunitySubscription and syncs the community's plan/status from a real subscription payload" do
      community = insert_community!(%{plan: "free", plan_status: "inactive"})

      payload =
        subscription_event_json("evt_sub_created_1", %{
          "id" => "sub_new_1",
          "customer" => "cus_1",
          "status" => "active",
          "current_period_start" => 1_700_000_000,
          "current_period_end" => 1_702_592_000,
          "cancel_at_period_end" => false,
          "canceled_at" => nil,
          "metadata" => %{"community_id" => community.id, "plan" => "creator"},
          "items" => %{"data" => [%{"price" => %{"id" => "price_creator_test"}}]}
        })

      # Before the fix this raised UndefinedFunctionError inside
      # first_item_price_id/get_in on the %Stripe.Subscription{} struct --
      # process_event/1's rescue clause re-raises, so this call itself would
      # crash the test rather than return an error tuple.
      assert Billing.handle_webhook(payload, sign(payload, @secret)) == :ok

      sub = Repo.get_by!(CommunitySubscription, stripe_subscription_id: "sub_new_1")
      assert sub.community_id == community.id
      assert sub.plan == "creator"
      assert sub.status == "active"
      assert sub.stripe_price_id == "price_creator_test"

      updated = Repo.get!(Community, community.id)
      assert updated.plan == "creator"
      assert updated.plan_status == "active"
    end

    test "a second webhook for the same subscription id updates in place, doesn't duplicate" do
      community = insert_community!(%{})

      base = %{
        "id" => "sub_update_1",
        "customer" => "cus_2",
        "current_period_start" => 1_700_000_000,
        "current_period_end" => 1_702_592_000,
        "cancel_at_period_end" => false,
        "canceled_at" => nil,
        "metadata" => %{"community_id" => community.id, "plan" => "creator"},
        "items" => %{"data" => [%{"price" => %{"id" => "price_creator_test"}}]}
      }

      p1 = subscription_event_json("evt_sub_u1", Map.put(base, "status", "trialing"))
      assert Billing.handle_webhook(p1, sign(p1, @secret)) == :ok

      p2 = subscription_event_json("evt_sub_u2", Map.put(base, "status", "active"))
      assert Billing.handle_webhook(p2, sign(p2, @secret)) == :ok

      assert Repo.aggregate(
               from(s in CommunitySubscription,
                 where: s.stripe_subscription_id == "sub_update_1"
               ),
               :count
             ) == 1

      assert Repo.get_by!(CommunitySubscription, stripe_subscription_id: "sub_update_1").status ==
               "active"
    end

    test "sets community.cancel_at when cancel_at_period_end is true" do
      community = insert_community!(%{})
      period_end = 1_702_592_000

      payload =
        subscription_event_json("evt_sub_cancel_1", %{
          "id" => "sub_cancel_1",
          "customer" => "cus_3",
          "status" => "active",
          "current_period_start" => 1_700_000_000,
          "current_period_end" => period_end,
          "cancel_at_period_end" => true,
          "canceled_at" => nil,
          "metadata" => %{"community_id" => community.id, "plan" => "platform"},
          "items" => %{"data" => [%{"price" => %{"id" => "price_platform_test"}}]}
        })

      assert Billing.handle_webhook(payload, sign(payload, @secret)) == :ok

      expected = period_end |> DateTime.from_unix!() |> DateTime.truncate(:second)
      assert Repo.get!(Community, community.id).cancel_at == expected
    end

    test "no-ops without error (or crashing) when metadata has no community_id" do
      payload =
        subscription_event_json("evt_sub_nometa", %{
          "id" => "sub_nometa",
          "customer" => "cus_4",
          "status" => "active",
          "current_period_start" => 1_700_000_000,
          "current_period_end" => 1_702_592_000,
          "cancel_at_period_end" => false,
          "canceled_at" => nil,
          "metadata" => %{},
          "items" => %{"data" => []}
        })

      assert Billing.handle_webhook(payload, sign(payload, @secret)) == :ok
      assert Repo.get_by(CommunitySubscription, stripe_subscription_id: "sub_nometa") == nil
    end

    test "falls back to inferring the plan from the price id when metadata has no plan" do
      System.put_env("STRIPE_PRICE_CREATOR", "price_creator_infer_test")
      on_exit(fn -> System.delete_env("STRIPE_PRICE_CREATOR") end)

      community = insert_community!(%{})

      payload =
        subscription_event_json("evt_sub_infer_1", %{
          "id" => "sub_infer_1",
          "customer" => "cus_6",
          "status" => "active",
          "current_period_start" => 1_700_000_000,
          "current_period_end" => 1_702_592_000,
          "cancel_at_period_end" => false,
          "canceled_at" => nil,
          "metadata" => %{"community_id" => community.id},
          "items" => %{"data" => [%{"price" => %{"id" => "price_creator_infer_test"}}]}
        })

      assert Billing.handle_webhook(payload, sign(payload, @secret)) == :ok

      assert Repo.get_by!(CommunitySubscription, stripe_subscription_id: "sub_infer_1").plan ==
               "creator"
    end
  end

  describe "invoice.payment_failed" do
    test "marks the subscription and community as past_due" do
      community = insert_community!(%{plan: "creator", plan_status: "active"})

      sub_payload =
        subscription_event_json("evt_sub_pf1", %{
          "id" => "sub_pf_1",
          "customer" => "cus_5",
          "status" => "active",
          "current_period_start" => 1_700_000_000,
          "current_period_end" => 1_702_592_000,
          "cancel_at_period_end" => false,
          "canceled_at" => nil,
          "metadata" => %{"community_id" => community.id, "plan" => "creator"},
          "items" => %{"data" => [%{"price" => %{"id" => "price_creator_test"}}]}
        })

      assert Billing.handle_webhook(sub_payload, sign(sub_payload, @secret)) == :ok

      # Deliberately no "metadata" on the invoice -- matches what a real
      # Stripe-generated subscription invoice actually looks like (Stripe
      # doesn't copy the subscription's metadata onto invoices it
      # auto-generates). community_id must come from the CommunitySubscription
      # row we just upserted above, not from invoice.metadata.
      invoice_payload =
        event_json("evt_invoice_pf1", "invoice.payment_failed", %{
          "object" => "invoice",
          "subscription" => "sub_pf_1"
        })

      assert Billing.handle_webhook(invoice_payload, sign(invoice_payload, @secret)) == :ok

      assert Repo.get_by!(CommunitySubscription, stripe_subscription_id: "sub_pf_1").status ==
               "past_due"

      assert Repo.get!(Community, community.id).plan_status == "past_due"
    end

    test "no-ops when the invoice has no subscription attached" do
      payload =
        event_json("evt_invoice_no_sub", "invoice.payment_failed", %{
          "object" => "invoice"
        })

      assert Billing.handle_webhook(payload, sign(payload, @secret)) == :ok
    end

    test "no-ops without crashing when the subscription isn't one we've ever seen" do
      payload =
        event_json("evt_invoice_unknown_sub", "invoice.payment_failed", %{
          "object" => "invoice",
          "subscription" => "sub_never_seen"
        })

      assert Billing.handle_webhook(payload, sign(payload, @secret)) == :ok
    end
  end

  describe "unhandled event types" do
    test "returns :ok and still records the audit row, without crashing" do
      payload = event_json("evt_unhandled_1", "customer.created", %{"object" => "customer"})

      assert Billing.handle_webhook(payload, sign(payload, @secret)) == :ok

      assert Repo.get_by!(StripeWebhookEvent, stripe_event_id: "evt_unhandled_1").processed_at !=
               nil
    end
  end

  # --- helpers ---

  defp sign(payload, secret) do
    timestamp = System.system_time(:second)
    signed_payload = "#{timestamp}.#{payload}"
    sig = :crypto.mac(:hmac, :sha256, secret, signed_payload) |> Base.encode16(case: :lower)
    "t=#{timestamp},v1=#{sig}"
  end

  defp event_json(event_id, type, object_attrs) do
    Jason.encode!(%{
      "id" => event_id,
      "object" => "event",
      "type" => type,
      "created" => System.system_time(:second),
      "livemode" => false,
      "pending_webhooks" => 0,
      "data" => %{"object" => object_attrs}
    })
  end

  # dispatch/1 matches "customer.subscription." <> _ regardless of suffix, so
  # created vs. updated doesn't change behavior -- always send "updated".
  defp subscription_event_json(event_id, sub_attrs) do
    event_json(
      event_id,
      "customer.subscription.updated",
      Map.put(sub_attrs, "object", "subscription")
    )
  end

  defp insert_community!(attrs) do
    n = System.unique_integer([:positive])
    default = %{name: "Community #{n}", slug: "community-#{n}"}

    %Community{}
    |> Community.changeset(Map.merge(default, attrs))
    |> Repo.insert!()
  end
end
