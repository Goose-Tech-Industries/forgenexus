defmodule ForgeNexus.Billing.CommunitySubscriptionTest do
  use ForgeNexus.DataCase, async: true

  alias ForgeNexus.Billing.CommunitySubscription

  describe "CommunitySubscription schema & changesets" do
    @cid Ecto.UUID.generate()
    @valid_attrs %{
      community_id: @cid,
      stripe_subscription_id: "sub_test123",
      stripe_customer_id: "cus_test123",
      stripe_price_id: "price_creator_monthly",
      plan: "creator",
      status: "active",
      current_period_start: ~U[2026-01-01 00:00:00Z],
      current_period_end: ~U[2026-02-01 00:00:00Z],
      cancel_at_period_end: false,
      canceled_at: nil,
      metadata: %{"seat_count" => 10}
    }

    test "valid changeset succeeds with all attributes" do
      cs = CommunitySubscription.changeset(%CommunitySubscription{}, @valid_attrs)
      assert cs.valid?
      assert get_field(cs, :community_id) == @cid
      assert get_field(cs, :stripe_subscription_id) == "sub_test123"
      assert get_field(cs, :plan) == "creator"
      assert get_field(cs, :status) == "active"
      assert get_field(cs, :cancel_at_period_end) == false
      assert get_field(cs, :metadata) == %{"seat_count" => 10}
    end

    test "validates required fields" do
      cs = CommunitySubscription.changeset(%CommunitySubscription{}, %{})
      refute cs.valid?
      assert "can't be blank" in errors_on(cs).community_id
      assert "can't be blank" in errors_on(cs).stripe_subscription_id
      assert "can't be blank" in errors_on(cs).plan
      assert "can't be blank" in errors_on(cs).status
    end

    test "validates plan inclusion" do
      for plan <- ~w(forum community creator platform enterprise houses) do
        cs =
          CommunitySubscription.changeset(
            %CommunitySubscription{},
            Map.put(@valid_attrs, :plan, plan)
          )

        assert cs.valid?
      end

      cs =
        CommunitySubscription.changeset(
          %CommunitySubscription{},
          Map.put(@valid_attrs, :plan, "megaplan")
        )

      refute cs.valid?
      assert "is invalid" in errors_on(cs).plan
    end

    test "validates status inclusion" do
      for status <- ~w(active trialing past_due canceled unpaid incomplete incomplete_expired) do
        cs =
          CommunitySubscription.changeset(
            %CommunitySubscription{},
            Map.put(@valid_attrs, :status, status)
          )

        assert cs.valid?
      end

      cs =
        CommunitySubscription.changeset(
          %CommunitySubscription{},
          Map.put(@valid_attrs, :status, "unknown_status")
        )

      refute cs.valid?
      assert "is invalid" in errors_on(cs).status
    end

    test "plans/0 returns valid paid tiers" do
      assert CommunitySubscription.plans() ==
               ~w(forum community creator platform enterprise houses)
    end

    test "statuses/0 returns valid subscription statuses" do
      assert CommunitySubscription.statuses() ==
               ~w(active trialing past_due canceled unpaid incomplete incomplete_expired)
    end
  end
end
