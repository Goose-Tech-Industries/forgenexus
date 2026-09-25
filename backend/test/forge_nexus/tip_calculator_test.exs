defmodule ForgeNexus.Voice.TipCalculatorStandaloneTest do
  use ExUnit.Case, async: true

  alias ForgeNexus.Voice.TipCalculator

  describe "Section 3C: Voice Revenue Split & Tip Calculator" do
    test "basic creator / starter community: 75% creator, stripe fee off platform share" do
      calc = TipCalculator.calculate(1000, "basic", "starter")

      assert calc.amount_cents == 1000
      assert calc.creator_amount_cents == 750
      assert calc.platform_gross_cents == 250
      # stripe: round(1000 * 0.029) + 30 = 29 + 30 = 59
      assert calc.stripe_fee_cents == 59
      # kickback: round(250 * 0.15) = 38
      assert calc.community_kickback_cents == 38
      # platform_net = 250 - 59 - 38 = 153
      assert calc.platform_net_cents == 153
      assert calc.creator_amount_cents == 750
    end

    test "top creator / enterprise community: 87% creator, 30% kickback" do
      calc = TipCalculator.calculate(1000, "top", "enterprise")

      assert calc.creator_amount_cents == 870
      assert calc.platform_gross_cents == 130
      # kickback: round(130 * 0.30) = 39
      assert calc.community_kickback_cents == 39
    end

    test "free community plan takes no kickback" do
      calc = TipCalculator.calculate(1000, "basic", "free")
      assert calc.community_kickback_cents == 0
    end

    test "platform net cents never goes negative on tiny transactions" do
      calc = TipCalculator.calculate(10, "top", "enterprise")
      assert calc.platform_net_cents >= 0
    end

    test "handles unknown creator tier and unknown community plan with sensible fallbacks" do
      calc = TipCalculator.calculate(1000, "unknown_tier", "unknown_plan")
      assert calc.creator_amount_cents == 750
      assert calc.platform_gross_cents == 250
      assert calc.community_kickback_cents == 38
    end
  end
end
