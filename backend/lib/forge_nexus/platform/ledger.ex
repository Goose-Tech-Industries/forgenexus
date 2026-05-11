defmodule ForgeNexus.Platform.Ledger do
  @moduledoc """
  Platform revenue ledger. Tracks every incoming dollar and auto-splits it
  between the infra fund and profit account. Provides running totals,
  burn rate, and runway calculations.

  ## Split ratios (by total community count)

  | Scale           | Infra | Profit |
  |-----------------|-------|--------|
  | < 50 communities | 40%   | 60%    |
  | 50-200          | 30%   | 70%    |
  | 200+            | 20%   | 80%    |
  """

  import Ecto.Query
  alias ForgeNexus.Repo

  @type entry_type :: String.t()
  @doc false
  def entry_types, do: ~w(community_fee tip_revenue redemption_revenue point_pack_sale premium_subscription marketplace_commission refund adjustment)

  def record_revenue(attrs) do
    amount = Map.get(attrs, :amount_cents) || Map.get(attrs, "amount_cents") || 0
    {infra, profit} = split(amount)

    full = Map.merge(attrs, %{
      infra_allocation_cents: infra,
      profit_allocation_cents: profit
    })

    %ForgeNexus.Platform.LedgerEntry{}
    |> ForgeNexus.Platform.LedgerEntry.changeset(full)
    |> Repo.insert()
  end

  def record_infra_cost(attrs) do
    %ForgeNexus.Platform.InfraCost{}
    |> ForgeNexus.Platform.InfraCost.changeset(attrs)
    |> Repo.insert()
  end

  def infra_fund_balance do
    total_infra_revenue =
      from(e in "platform_ledger_entries", select: coalesce(sum(e.infra_allocation_cents), 0))
      |> Repo.one()

    total_infra_costs =
      from(c in "infra_costs", select: coalesce(sum(c.amount_cents), 0))
      |> Repo.one()

    total_infra_revenue - total_infra_costs
  end

  def profit_balance do
    from(e in "platform_ledger_entries", select: coalesce(sum(e.profit_allocation_cents), 0))
    |> Repo.one()
  end

  def total_revenue do
    from(e in "platform_ledger_entries",
      where: e.amount_cents > 0,
      select: coalesce(sum(e.amount_cents), 0)
    )
    |> Repo.one()
  end

  def monthly_burn_rate do
    thirty_days_ago = Date.utc_today() |> Date.add(-30)

    from(c in "infra_costs",
      where: c.period_start >= ^thirty_days_ago,
      select: coalesce(sum(c.amount_cents), 0)
    )
    |> Repo.one()
  end

  def runway_months do
    balance = infra_fund_balance()
    burn = monthly_burn_rate()

    if burn > 0 do
      Float.round(balance / burn, 1)
    else
      999.0
    end
  end

  def dashboard do
    %{
      infra_fund_balance_cents: infra_fund_balance(),
      profit_balance_cents: profit_balance(),
      total_revenue_cents: total_revenue(),
      monthly_burn_rate_cents: monthly_burn_rate(),
      runway_months: runway_months(),
      split_ratio: current_split_ratio()
    }
  end

  def revenue_by_type(days \\ 30) do
    since = DateTime.utc_now() |> DateTime.add(-days * 86400, :second)

    from(e in "platform_ledger_entries",
      where: e.inserted_at >= ^since and e.amount_cents > 0,
      group_by: e.type,
      select: {e.type, sum(e.amount_cents)}
    )
    |> Repo.all()
    |> Map.new()
  end

  def recent_entries(limit \\ 50) do
    from(e in ForgeNexus.Platform.LedgerEntry,
      order_by: [desc: :inserted_at],
      limit: ^limit
    )
    |> Repo.all()
  end

  defp split(amount) when is_integer(amount) do
    {infra_pct, _profit_pct} = current_split_ratio()
    infra = round(amount * infra_pct)
    profit = amount - infra
    {infra, profit}
  end

  defp current_split_ratio do
    community_count =
      from(c in "communities", where: c.is_active == true, select: count())
      |> Repo.one()

    cond do
      community_count < 50 -> {0.40, 0.60}
      community_count < 200 -> {0.30, 0.70}
      true -> {0.20, 0.80}
    end
  end
end
