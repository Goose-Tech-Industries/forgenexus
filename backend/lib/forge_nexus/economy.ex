defmodule ForgeNexus.Economy do
  @moduledoc "Multi-currency economy system with balances, transactions, transfers, and interest."
  import Ecto.Query
  alias ForgeNexus.Repo

  alias ForgeNexus.Economy.{
    Currency,
    UserBalance,
    Transaction,
    PointTransaction,
    PointConfig,
    PointPack,
    PointPackPurchase
  }

  alias ForgeNexus.Accounts.User

  @default_rates %{
    "post_created" => 5,
    "thread_created" => 10,
    "reaction_received" => 2,
    "badge_earned" => 25,
    "daily_login" => 1,
    "best_answer" => 15
  }

  def get_points(user_id) do
    Repo.one(from u in User, where: u.id == ^user_id, select: u.points) || 0
  end

  def award_points(user_id, reason, opts) when is_list(opts) do
    amount = Keyword.get(opts, :amount) || get_rate(reason)
    ref_type = Keyword.get(opts, :reference_type)
    ref_id = Keyword.get(opts, :reference_id)
    description = Keyword.get(opts, :description)

    if amount > 0 do
      Repo.transaction(fn ->
        {1, [%{points: new_balance}]} =
          from(u in User, where: u.id == ^user_id, select: %{points: u.points})
          |> Repo.update_all(inc: [points: amount])

        %PointTransaction{}
        |> PointTransaction.changeset(%{
          user_id: user_id,
          amount: amount,
          balance_after: new_balance,
          reason: reason,
          reference_type: ref_type,
          reference_id: ref_id,
          description: description
        })
        |> Repo.insert!()
      end)
    else
      {:ok, :no_points}
    end
  end

  def award_points(user_id, currency_id, amount) when is_integer(amount) and amount > 0 do
    Repo.transaction(fn ->
      get_balance(user_id, currency_id)

      {1, [%{balance: new_bal}]} =
        from(ub in UserBalance,
          where: ub.user_id == ^user_id and ub.currency_id == ^currency_id,
          select: %{balance: ub.balance}
        )
        |> Repo.update_all(inc: [balance: amount, lifetime_earned: amount])

      create_transaction!(%{
        user_id: user_id,
        currency_id: currency_id,
        amount: amount,
        balance_after: new_bal,
        type: "award"
      })

      new_bal
    end)
  end

  def deduct_points(user_id, amount, reason, opts) when is_binary(reason) do
    deduct_legacy_points(user_id, amount, reason, opts)
  end

  def deduct_legacy_points(user_id, amount, reason, opts \\ []) do
    if amount <= 0, do: raise(ArgumentError, "amount must be positive")

    Repo.transaction(fn ->
      case from(u in User,
             where: u.id == ^user_id and u.points >= ^amount,
             select: %{points: u.points}
           )
           |> Repo.update_all(inc: [points: -amount]) do
        {0, _} ->
          Repo.rollback(:insufficient_points)

        {1, [%{points: new_balance}]} ->
          %PointTransaction{}
          |> PointTransaction.changeset(%{
            user_id: user_id,
            amount: -amount,
            balance_after: new_balance,
            reason: reason,
            reference_type: Keyword.get(opts, :reference_type),
            reference_id: Keyword.get(opts, :reference_id),
            description: Keyword.get(opts, :description)
          })
          |> Repo.insert!()
      end
    end)
  end

  def transaction_history(user_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 25)

    PointTransaction
    |> where([t], t.user_id == ^user_id)
    |> order_by(desc: :inserted_at)
    |> limit(^limit)
    |> Repo.all()
  end

  def leaderboard(limit \\ 20) do
    User
    |> where([u], u.points > 0)
    |> order_by(desc: :points)
    |> limit(^limit)
    |> select([u], %{id: u.id, username: u.username, avatar_url: u.avatar_url, points: u.points})
    |> Repo.all()
  end

  def get_rate(action) do
    case Repo.get_by(PointConfig, action: action, is_active: true) do
      nil -> Map.get(@default_rates, action, 0)
      config -> config.points
    end
  end

  def list_config do
    existing = PointConfig |> Repo.all() |> Map.new(fn c -> {c.action, c} end)

    Enum.map(@default_rates, fn {action, default} ->
      case Map.get(existing, action) do
        nil ->
          %{action: action, points: default, is_active: true, is_default: true}

        config ->
          %{
            action: config.action,
            points: config.points,
            is_active: config.is_active,
            is_default: false,
            id: config.id
          }
      end
    end)
  end

  def update_config(action, points, is_active) do
    case Repo.get_by(PointConfig, action: action) do
      nil ->
        %PointConfig{}
        |> PointConfig.changeset(%{action: action, points: points, is_active: is_active})
        |> Repo.insert()

      existing ->
        existing
        |> PointConfig.changeset(%{points: points, is_active: is_active})
        |> Repo.update()
    end
  end

  # Multi-currency system

  def list_currencies do
    Currency |> where([c], c.is_active == true) |> order_by(:name) |> Repo.all()
  end

  def get_default_currency do
    Repo.one(from c in Currency, where: c.is_default == true and c.is_active == true, limit: 1)
  end

  def get_balance(user_id, currency_id) do
    case Repo.one(
           from ub in UserBalance,
             where: ub.user_id == ^user_id and ub.currency_id == ^currency_id,
             select: ub.balance
         ) do
      nil ->
        %UserBalance{}
        |> UserBalance.changeset(%{
          user_id: user_id,
          currency_id: currency_id,
          balance: 0,
          lifetime_earned: 0
        })
        |> Repo.insert!(on_conflict: :nothing, conflict_target: [:user_id, :currency_id])

      balance ->
        balance
    end
  end

  def deduct_points(user_id, currency_id, amount) when is_integer(amount) and amount > 0 do
    Repo.transaction(fn ->
      case from(ub in UserBalance,
             where:
               ub.user_id == ^user_id and ub.currency_id == ^currency_id and ub.balance >= ^amount,
             select: %{balance: ub.balance}
           )
           |> Repo.update_all(inc: [balance: -amount]) do
        {0, _} ->
          Repo.rollback(:insufficient_balance)

        {1, [%{balance: new_bal}]} ->
          create_transaction!(%{
            user_id: user_id,
            currency_id: currency_id,
            amount: -amount,
            balance_after: new_bal,
            type: "deduct"
          })

          new_bal
      end
    end)
  end

  def transfer_points(from_id, to_id, currency_id, amount)
      when is_integer(amount) and amount > 0 do
    Repo.transaction(fn ->
      case from(ub in UserBalance,
             where:
               ub.user_id == ^from_id and ub.currency_id == ^currency_id and ub.balance >= ^amount,
             select: %{balance: ub.balance}
           )
           |> Repo.update_all(inc: [balance: -amount]) do
        {0, _} ->
          Repo.rollback(:insufficient_balance)

        {1, [%{balance: sender_bal}]} ->
          create_transaction!(%{
            user_id: from_id,
            currency_id: currency_id,
            amount: -amount,
            balance_after: sender_bal,
            type: "transfer",
            reason: "transfer_to:" <> to_id
          })

          get_balance(to_id, currency_id)

          {1, [%{balance: recv_bal}]} =
            from(ub in UserBalance,
              where: ub.user_id == ^to_id and ub.currency_id == ^currency_id,
              select: %{balance: ub.balance}
            )
            |> Repo.update_all(inc: [balance: amount, lifetime_earned: amount])

          create_transaction!(%{
            user_id: to_id,
            currency_id: currency_id,
            amount: amount,
            balance_after: recv_bal,
            type: "transfer",
            reason: "transfer_from:" <> from_id
          })

          :ok
      end
    end)
  end

  def get_leaderboard(currency_id, limit \\ 10) do
    UserBalance
    |> where([ub], ub.currency_id == ^currency_id and ub.balance > 0)
    |> order_by(desc: :balance)
    |> limit(^limit)
    |> join(:inner, [ub], u in User, on: ub.user_id == u.id)
    |> select([ub, u], %{
      user_id: u.id,
      username: u.username,
      slug: u.slug,
      avatar_url: u.avatar_url,
      balance: ub.balance
    })
    |> Repo.all()
  end

  def get_user_rank(user_id, currency_id) do
    bal = get_balance(user_id, currency_id)

    count =
      Repo.one(
        from ub in UserBalance,
          where: ub.currency_id == ^currency_id and ub.balance > ^bal,
          select: count(ub.id)
      )

    count + 1
  end

  def create_transaction(attrs),
    do: %Transaction{} |> Transaction.changeset(attrs) |> Repo.insert()

  defp create_transaction!(attrs),
    do: %Transaction{} |> Transaction.changeset(attrs) |> Repo.insert!()

  # --- Point Packs (real money → economy points) ---

  def list_point_packs(community_id) do
    PointPack
    |> where([p], p.community_id == ^community_id and p.is_active == true)
    |> order_by(asc: :position)
    |> Repo.all()
  end

  def get_point_pack!(id), do: Repo.get!(PointPack, id)

  def create_point_pack(attrs) do
    %PointPack{} |> PointPack.changeset(attrs) |> Repo.insert()
  end

  def update_point_pack(id, attrs) do
    get_point_pack!(id) |> PointPack.changeset(attrs) |> Repo.update()
  end

  def purchase_point_pack(pack_id, user_id, community_id, stripe_pi_id \\ nil) do
    pack = get_point_pack!(pack_id)
    total_points = PointPack.total_points(pack)

    Repo.transaction(fn ->
      award_points(user_id, "point_pack_purchase",
        amount: total_points,
        description: "Purchased #{pack.name} (#{pack.points}+#{pack.bonus_points} bonus)"
      )

      purchase =
        %PointPackPurchase{}
        |> PointPackPurchase.changeset(%{
          pack_id: pack.id,
          user_id: user_id,
          community_id: community_id,
          points_granted: total_points,
          amount_cents: pack.price_cents,
          stripe_payment_intent_id: stripe_pi_id
        })
        |> Repo.insert!()

      ForgeNexus.Platform.Ledger.record_revenue(%{
        community_id: community_id,
        type: "point_pack_sale",
        source: "point_pack",
        amount_cents: pack.price_cents,
        reference_type: "point_pack_purchase",
        reference_id: purchase.id,
        description: "#{pack.name} purchased by user"
      })

      purchase
    end)
  end

  def apply_interest(currency_id, rate_pct) when is_number(rate_pct) and rate_pct > 0 do
    bals =
      from(ub in UserBalance,
        where: ub.currency_id == ^currency_id and ub.balance > 0,
        select: %{user_id: ub.user_id, balance: ub.balance}
      )
      |> Repo.all()

    Enum.each(bals, fn %{user_id: uid, balance: bal} ->
      interest = trunc(bal * rate_pct / 100)
      if interest > 0, do: award_points(uid, currency_id, interest)
    end)

    {:ok, length(bals)}
  end

  def get_currency_by_slug(slug) do
    Repo.one(from c in Currency, where: c.slug == ^slug and c.is_active == true)
  end
end
