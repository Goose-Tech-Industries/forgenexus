defmodule ForgeNexus.Voice.TipCalculator do
  @moduledoc """
  Revenue split engine for all monetary transactions on the platform.
  Calculates the three-way split: creator payout, community owner kickback,
  and platform net revenue, after Stripe processing fees.

  ## Creator tiers (platform take from gross)

  | Tier  | Platform | Creator |
  |-------|----------|---------|
  | basic | 25%      | 75%     |
  | mid   | 20%      | 80%     |
  | top   | 13%      | 87%     |

  ## Community kickback (% of platform's cut returned to community owner)

  | Community plan | Kickback |
  |----------------|----------|
  | starter        | 15%      |
  | pro            | 20%      |
  | enterprise     | 25%      |

  ## Stripe processing

  2.9% + $0.30 per transaction (US domestic cards).
  Deducted from the platform's share, never from the creator's payout.
  """

  @creator_tiers %{
    "basic" => 0.25,
    "mid" => 0.20,
    "top" => 0.13
  }

  @community_kickback_rates %{
    "starter" => 0.15,
    "pro" => 0.20,
    "enterprise" => 0.25
  }

  @stripe_percent 0.029
  @stripe_flat_cents 30

  @type breakdown :: %{
          amount_cents: integer(),
          stripe_fee_cents: integer(),
          creator_amount_cents: integer(),
          platform_gross_cents: integer(),
          community_kickback_cents: integer(),
          platform_net_cents: integer(),
          creator_tier: String.t(),
          community_plan: String.t(),
          effective_platform_rate: float()
        }

  @spec calculate(integer(), String.t(), String.t()) :: breakdown()
  def calculate(amount_cents, creator_tier \\ "basic", community_plan \\ "starter")
      when is_integer(amount_cents) and amount_cents > 0 do
    platform_rate = Map.get(@creator_tiers, creator_tier, 0.25)
    kickback_rate = Map.get(@community_kickback_rates, community_plan, 0.15)

    stripe_fee = round(amount_cents * @stripe_percent) + @stripe_flat_cents
    creator_amount = round(amount_cents * (1 - platform_rate))
    platform_gross = amount_cents - creator_amount
    community_kickback = round(platform_gross * kickback_rate)
    platform_net = platform_gross - stripe_fee - community_kickback

    %{
      amount_cents: amount_cents,
      stripe_fee_cents: stripe_fee,
      creator_amount_cents: creator_amount,
      platform_gross_cents: platform_gross,
      community_kickback_cents: community_kickback,
      platform_net_cents: max(platform_net, 0),
      creator_tier: creator_tier,
      community_plan: community_plan,
      effective_platform_rate: if(amount_cents > 0, do: Float.round(platform_net / amount_cents * 100, 1), else: 0.0)
    }
  end

  def tier_for_user(_user_id) do
    # TODO: look up from user's creator profile / subscription tier
    "basic"
  end

  def community_plan_for_room(_room_id) do
    # TODO: look up from the community's subscription plan
    "starter"
  end

  def creator_tiers, do: @creator_tiers
  def community_kickback_rates, do: @community_kickback_rates

  @doc "Preview the split for display in the UI before confirming a tip."
  def preview(amount_cents, creator_tier \\ "basic", community_plan \\ "starter") do
    calc = calculate(amount_cents, creator_tier, community_plan)

    %{
      you_pay: format_cents(amount_cents),
      creator_gets: format_cents(calc.creator_amount_cents),
      platform_fee: format_cents(calc.platform_gross_cents),
      community_earns: format_cents(calc.community_kickback_cents),
      processing: format_cents(calc.stripe_fee_cents)
    }
  end

  defp format_cents(cents) when is_integer(cents) do
    "$#{Float.round(cents / 100, 2)}"
  end
end
