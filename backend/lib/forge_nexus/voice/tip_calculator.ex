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

  Keyed to `ForgeNexus.Communities.Community`'s real plan ladder (`free forum
  community creator platform enterprise houses`), plus the legacy `starter`/
  `social` plan names Community still accepts for migration compatibility —
  mapped to their nearest current-plan equivalent by feature parity.

  | Community plan          | Kickback |
  |--------------------------|----------|
  | free                     | 0%       |
  | forum                    | 10%      |
  | community                | 15%      |
  | creator                  | 20%      |
  | platform                 | 25%      |
  | enterprise               | 30%      |
  | houses                   | 25%      |
  | starter (legacy → community) | 15%  |
  | social (legacy → creator)    | 20%  |

  ## Stripe processing

  2.9% + $0.30 per transaction (US domestic cards).
  Deducted from the platform's share, never from the creator's payout.
  """

  alias ForgeNexus.Repo
  alias ForgeNexus.Accounts.User
  alias ForgeNexus.Voice.Room

  # Creator payout tier — admin-granted via AdminUserController, stored on
  # ForgeNexus.Accounts.User.creator_tier. Deliberately ahead of Twitch's
  # typical 50-70% creator split, kept a bit under Kick's 95% so the platform
  # take can still cover Stripe fees + infra at scale.
  @creator_tiers %{
    "basic" => 0.25,
    "mid" => 0.20,
    "top" => 0.13
  }

  @community_kickback_rates %{
    "free" => 0.0,
    "forum" => 0.10,
    "community" => 0.15,
    "creator" => 0.20,
    "platform" => 0.25,
    "enterprise" => 0.30,
    "houses" => 0.25,
    # Legacy plan names — Community still validates these; mapped to the
    # current-plan tier with the closest feature parity.
    "starter" => 0.15,
    "social" => 0.20
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
      effective_platform_rate:
        if(amount_cents > 0, do: Float.round(platform_net / amount_cents * 100, 1), else: 0.0)
    }
  end

  @doc "Creator's payout tier. Defaults to \"basic\" if the user can't be found."
  def tier_for_user(nil), do: "basic"

  def tier_for_user(user_id) do
    case Repo.get(User, user_id) do
      %User{creator_tier: tier} when is_binary(tier) -> tier
      _ -> "basic"
    end
  end

  @doc "The room's community's billing plan. Defaults to \"free\" if either can't be found."
  def community_plan_for_room(nil), do: "free"

  def community_plan_for_room(room_id) do
    Room
    |> Repo.get(room_id)
    |> case do
      nil -> "free"
      room -> room |> Repo.preload(:community) |> Map.get(:community)
    end
    |> case do
      %{plan: plan} when is_binary(plan) -> plan
      _ -> "free"
    end
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
