defmodule ForgeNexus.Voice.TipCalculatorTest do
  # async: false — a "fresh room has no community" test intermittently saw a
  # different test's community leak in under async: true (Sandbox owned-mode
  # concurrency), even though each test inserts and queries by its own fresh
  # UUID. Running sequentially eliminates that whole class of flakiness while
  # this gets root-caused properly.
  use ForgeNexus.DataCase, async: false

  alias ForgeNexus.Voice.TipCalculator
  alias ForgeNexus.Communities.Community
  alias ForgeNexus.Accounts.User
  alias ForgeNexus.Voice.Room

  describe "calculate/3 — split math" do
    test "basic creator / starter community: 75% creator, stripe fee off the platform share" do
      calc = TipCalculator.calculate(1000, "basic", "starter")

      assert calc.amount_cents == 1000
      # 75% of 1000 = 750
      assert calc.creator_amount_cents == 750
      assert calc.platform_gross_cents == 250
      # stripe: round(1000 * 0.029) + 30 = 29 + 30 = 59
      assert calc.stripe_fee_cents == 59
      # kickback: round(250 * 0.15) = 38
      assert calc.community_kickback_cents == 38
      # platform_net = 250 - 59 - 38 = 153
      assert calc.platform_net_cents == 153
      # creator's payout is never touched by stripe fee or kickback
      assert calc.creator_amount_cents == 750
    end

    test "top creator / enterprise community: creator take rises, platform share shrinks further" do
      calc = TipCalculator.calculate(1000, "top", "enterprise")

      # 87% of 1000 = 870
      assert calc.creator_amount_cents == 870
      assert calc.platform_gross_cents == 130
      # kickback: round(130 * 0.30) = 39
      assert calc.community_kickback_cents == 39
    end

    test "free community plan takes no kickback at all" do
      calc = TipCalculator.calculate(1000, "basic", "free")
      assert calc.community_kickback_cents == 0
    end

    test "platform_net_cents never goes negative even on tiny tips that don't cover the stripe flat fee" do
      calc = TipCalculator.calculate(10, "top", "enterprise")
      assert calc.platform_net_cents == 0
    end

    test "unknown creator tier falls back to the basic (25%) platform rate" do
      calc = TipCalculator.calculate(1000, "nonexistent_tier", "free")
      assert calc.platform_gross_cents == 250
    end

    test "unknown community plan falls back to the 15% kickback rate" do
      calc = TipCalculator.calculate(1000, "basic", "nonexistent_plan")
      assert calc.community_kickback_cents == 38
    end
  end

  describe "community_kickback_rates/0 stays in sync with Community.plans/0" do
    test "every real community plan has an explicit kickback rate — no silent Map.get fallback" do
      rates = TipCalculator.community_kickback_rates()

      current_plans = ~w(free forum community creator platform enterprise houses)

      missing = Enum.reject(current_plans, &Map.has_key?(rates, &1))

      assert missing == [],
             "Community.plans/0 has plan(s) with no explicit kickback rate in " <>
               "TipCalculator: #{inspect(missing)}. Falling through to the default " <>
               "rate here is exactly the bug this test exists to catch."
    end

    test "every key in the rate table is still a plan Community actually accepts" do
      rates = TipCalculator.community_kickback_rates()
      known_plans = Community.plans()

      stale = Enum.reject(Map.keys(rates), &(&1 in known_plans))

      assert stale == [],
             "TipCalculator has kickback rate(s) for plan(s) Community no longer " <>
               "recognizes: #{inspect(stale)}"
    end
  end

  describe "tier_for_user/1" do
    test "returns the user's real creator_tier" do
      user = insert_user!(%{creator_tier: "top"})
      assert TipCalculator.tier_for_user(user.id) == "top"
    end

    test "defaults to basic for a user with no explicit tier set" do
      user = insert_user!(%{})
      assert user.creator_tier == "basic"
      assert TipCalculator.tier_for_user(user.id) == "basic"
    end

    test "defaults to basic for a user id that doesn't exist" do
      assert TipCalculator.tier_for_user(Ecto.UUID.generate()) == "basic"
    end

    test "defaults to basic for nil" do
      assert TipCalculator.tier_for_user(nil) == "basic"
    end
  end

  describe "community_plan_for_room/1" do
    test "returns the room's community's plan" do
      community = insert_community!(%{plan: "platform"})
      room = insert_room!(%{community_id: community.id})

      assert TipCalculator.community_plan_for_room(room.id) == "platform"
    end

    test "defaults to free for a room with no community" do
      room = insert_room!(%{})
      assert room.community_id == nil
      assert TipCalculator.community_plan_for_room(room.id) == "free"
    end

    test "defaults to free for a room id that doesn't exist" do
      assert TipCalculator.community_plan_for_room(Ecto.UUID.generate()) == "free"
    end

    test "defaults to free for nil" do
      assert TipCalculator.community_plan_for_room(nil) == "free"
    end
  end

  describe "end to end: create_money_tip/1 bakes in the real tier + plan" do
    test "a tip to a top-tier creator in a platform-plan community's room gets the real split" do
      creator = insert_user!(%{creator_tier: "top"})
      community = insert_community!(%{plan: "platform"})
      room = insert_room!(%{community_id: community.id})

      {:ok, tip} =
        ForgeNexus.Voice.create_money_tip(%{
          recipient_id: creator.id,
          room_id: room.id,
          amount_cents: 1000
        })

      assert tip.creator_tier == "top"
      assert tip.community_plan == "platform"
      # 87% of 1000
      assert tip.creator_amount_cents == 870
    end
  end

  # --- fixtures ---

  defp insert_user!(attrs) do
    n = System.unique_integer([:positive])

    %User{}
    |> User.registration_changeset(%{
      username: "tipuser#{n}",
      email: "tipuser#{n}@example.com",
      password: "supersecret123"
    })
    |> Repo.insert!()
    |> then(fn user ->
      if attrs == %{} do
        user
      else
        user |> User.admin_changeset(attrs) |> Repo.update!()
      end
    end)
  end

  defp insert_community!(attrs) do
    n = System.unique_integer([:positive])

    default = %{name: "Community #{n}", slug: "community-#{n}"}

    %Community{}
    |> Community.changeset(Map.merge(default, attrs))
    |> Repo.insert!()
  end

  defp insert_room!(attrs) do
    n = System.unique_integer([:positive])

    default = %{name: "Room #{n}"}

    %Room{}
    |> Room.changeset(Map.merge(default, attrs))
    |> Repo.insert!()
  end
end
