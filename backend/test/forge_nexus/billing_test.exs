defmodule ForgeNexus.BillingTest do
  use ForgeNexus.DataCase, async: false

  alias ForgeNexus.Billing
  alias ForgeNexus.Communities.Community

  # These tests exercise the env-var-driven "is this plan actually
  # configured yet" behavior. STRIPE_PRICE_HOUSES_* aren't set in any
  # environment yet (no Stripe account exists), so the "not configured"
  # path is the real, current, honest behavior — not a mocked edge case.
  # async: false because tests mutate process env vars.

  describe "houses_price_ids/0" do
    test "returns nil for both when env vars are unset" do
      System.delete_env("STRIPE_PRICE_HOUSES_BASE")
      System.delete_env("STRIPE_PRICE_HOUSES_PER_CREATOR")

      assert Billing.houses_price_ids() == %{base: nil, per_creator: nil}
    end

    test "reflects whatever is actually set" do
      System.put_env("STRIPE_PRICE_HOUSES_BASE", "price_base_test")
      System.put_env("STRIPE_PRICE_HOUSES_PER_CREATOR", "price_extra_test")

      on_exit(fn ->
        System.delete_env("STRIPE_PRICE_HOUSES_BASE")
        System.delete_env("STRIPE_PRICE_HOUSES_PER_CREATOR")
      end)

      assert Billing.houses_price_ids() == %{
               base: "price_base_test",
               per_creator: "price_extra_test"
             }
    end
  end

  describe "create_checkout_session/2 — houses" do
    setup do
      System.delete_env("STRIPE_PRICE_HOUSES_BASE")
      System.delete_env("STRIPE_PRICE_HOUSES_PER_CREATOR")
      :ok
    end

    test "returns price_not_configured without ever calling Stripe, matching the other 5 tiers before their env vars are set" do
      community = insert_community!(%{plan: "houses", member_count: 3})

      assert Billing.create_checkout_session(community, "houses") ==
               {:error, {:price_not_configured, "houses"}}
    end

    test "still rejects a plan that isn't a real plan at all" do
      community = insert_community!(%{plan: "houses"})

      assert Billing.create_checkout_session(community, "not_a_real_plan") ==
               {:error, :invalid_plan}
    end
  end

  describe "plan_catalog/0" do
    test "contains 5 flat tiers with defined names and monthly cents" do
      catalog = Billing.plan_catalog()
      plans = Enum.map(catalog, fn {p, _info} -> p end)

      assert plans == ["forum", "community", "creator", "platform", "enterprise"]

      assert {"forum", %{name: "Forum", monthly_cents: 1900}} =
               Enum.find(catalog, fn {p, _} -> p == "forum" end)

      assert {"enterprise", %{name: "Enterprise", monthly_cents: 35000}} =
               Enum.find(catalog, fn {p, _} -> p == "enterprise" end)
    end
  end

  describe "price_id_for/1" do
    test "returns configured price id from env vars" do
      System.put_env("STRIPE_PRICE_FORUM", "price_forum_test")
      on_exit(fn -> System.delete_env("STRIPE_PRICE_FORUM") end)

      assert Billing.price_id_for("forum") == "price_forum_test"
    end

    test "houses isn't a flat-price plan, so it never matches a single price_id" do
      System.put_env("STRIPE_PRICE_HOUSES_BASE", "price_base_test")
      on_exit(fn -> System.delete_env("STRIPE_PRICE_HOUSES_BASE") end)

      assert Billing.price_id_for("houses") == nil
    end

    test "unknown plan returns nil rather than raising" do
      assert Billing.price_id_for("not_a_real_plan") == nil
    end
  end

  describe "create_checkout_session/2 — flat plans" do
    test "returns price_not_configured when price id is unset" do
      System.delete_env("STRIPE_PRICE_COMMUNITY")
      community = insert_community!(%{plan: "free"})

      assert Billing.create_checkout_session(community, "community") ==
               {:error, {:price_not_configured, "community"}}
    end
  end

  # --- fixtures ---

  defp insert_community!(attrs) do
    n = System.unique_integer([:positive])
    default = %{name: "Community #{n}", slug: "community-#{n}"}

    %Community{}
    |> Community.changeset(Map.merge(default, attrs))
    |> Repo.insert!()
  end
end
