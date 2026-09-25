defmodule ForgeNexus.Economy.EconomySchemasTest do
  use ForgeNexus.DataCase, async: true

  alias ForgeNexus.Economy.{
    Currency,
    PointConfig,
    PointPack,
    PointPackPurchase,
    PointTransaction,
    Transaction,
    UserBalance
  }

  describe "Currency schema" do
    test "valid currency changeset" do
      attrs = %{
        name: "Gold Coins",
        slug: "gold",
        icon: "coin",
        is_default: true,
        is_tradeable: true
      }

      changeset = Currency.changeset(%Currency{}, attrs)

      assert changeset.valid?
      assert get_change(changeset, :slug) == "gold"
    end

    test "requires name and slug" do
      changeset = Currency.changeset(%Currency{}, %{})
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).name
      assert "can't be blank" in errors_on(changeset).slug
    end
  end

  describe "PointConfig schema" do
    test "valid point config changeset" do
      attrs = %{action: "daily_login", points: 10, is_active: true}
      changeset = PointConfig.changeset(%PointConfig{}, attrs)

      assert changeset.valid?
      assert get_change(changeset, :points) == 10
    end

    test "requires action and points" do
      changeset = PointConfig.changeset(%PointConfig{}, %{})
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).action
      assert "can't be blank" in errors_on(changeset).points
    end
  end

  describe "PointPack schema" do
    test "valid point pack changeset" do
      attrs = %{
        name: "Starter Pack",
        points: 500,
        bonus_points: 50,
        price_cents: 499,
        currency: "usd",
        emoji: "⭐"
      }

      changeset = PointPack.changeset(%PointPack{}, attrs)
      assert changeset.valid?
    end

    test "requires name, points, and price_cents" do
      changeset = PointPack.changeset(%PointPack{}, %{})
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).name
      assert "can't be blank" in errors_on(changeset).points
      assert "can't be blank" in errors_on(changeset).price_cents
    end

    test "validates numeric bounds" do
      invalid =
        PointPack.changeset(%PointPack{}, %{
          name: "P",
          points: 0,
          price_cents: -10,
          bonus_points: -1
        })

      refute invalid.valid?
      assert "must be greater than 0" in errors_on(invalid).points
      assert "must be greater than 0" in errors_on(invalid).price_cents
      assert "must be greater than or equal to 0" in errors_on(invalid).bonus_points
    end

    test "total_points/1 adds bonus_points" do
      pack_with_bonus = %PointPack{points: 1000, bonus_points: 200}
      assert PointPack.total_points(pack_with_bonus) == 1200

      pack_without_bonus = %PointPack{points: 1000, bonus_points: nil}
      assert PointPack.total_points(pack_without_bonus) == 1000
    end
  end

  describe "PointPackPurchase schema" do
    test "valid purchase changeset" do
      attrs = %{
        user_id: Ecto.UUID.generate(),
        points_granted: 500,
        amount_cents: 499,
        status: "completed",
        stripe_payment_intent_id: "pi_123456"
      }

      changeset = PointPackPurchase.changeset(%PointPackPurchase{}, attrs)
      assert changeset.valid?
    end

    test "requires user_id, points_granted, and amount_cents" do
      changeset = PointPackPurchase.changeset(%PointPackPurchase{}, %{})
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).user_id
      assert "can't be blank" in errors_on(changeset).points_granted
      assert "can't be blank" in errors_on(changeset).amount_cents
    end

    test "validates status inclusion" do
      invalid =
        PointPackPurchase.changeset(%PointPackPurchase{}, %{
          user_id: Ecto.UUID.generate(),
          points_granted: 1,
          amount_cents: 1,
          status: "unknown"
        })

      refute invalid.valid?
      assert "is invalid" in errors_on(invalid).status

      for s <- ~w(pending completed failed refunded) do
        assert PointPackPurchase.changeset(%PointPackPurchase{}, %{
                 user_id: Ecto.UUID.generate(),
                 points_granted: 1,
                 amount_cents: 1,
                 status: s
               }).valid?
      end
    end
  end

  describe "PointTransaction schema" do
    test "valid point transaction changeset" do
      attrs = %{
        user_id: Ecto.UUID.generate(),
        amount: 50,
        balance_after: 150,
        reason: "thread_created",
        description: "Points for posting"
      }

      changeset = PointTransaction.changeset(%PointTransaction{}, attrs)
      assert changeset.valid?
    end

    test "requires user_id, amount, balance_after, and reason" do
      changeset = PointTransaction.changeset(%PointTransaction{}, %{})
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).user_id
      assert "can't be blank" in errors_on(changeset).amount
      assert "can't be blank" in errors_on(changeset).balance_after
      assert "can't be blank" in errors_on(changeset).reason
    end
  end

  describe "Transaction schema" do
    test "valid multi-currency transaction" do
      attrs = %{
        user_id: Ecto.UUID.generate(),
        currency_id: Ecto.UUID.generate(),
        amount: -25,
        balance_after: 75,
        type: "deduct",
        reason: "shop_purchase"
      }

      changeset = Transaction.changeset(%Transaction{}, attrs)
      assert changeset.valid?
    end

    test "requires user_id, currency_id, amount, balance_after, and type" do
      changeset = Transaction.changeset(%Transaction{}, %{})
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).user_id
      assert "can't be blank" in errors_on(changeset).currency_id
      assert "can't be blank" in errors_on(changeset).amount
      assert "can't be blank" in errors_on(changeset).balance_after
      assert "can't be blank" in errors_on(changeset).type
    end

    test "validates type inclusion" do
      invalid =
        Transaction.changeset(%Transaction{}, %{
          user_id: Ecto.UUID.generate(),
          currency_id: Ecto.UUID.generate(),
          amount: 1,
          balance_after: 1,
          type: "fraud"
        })

      refute invalid.valid?
      assert "is invalid" in errors_on(invalid).type

      for t <- ~w(award deduct transfer interest refund) do
        assert Transaction.changeset(%Transaction{}, %{
                 user_id: Ecto.UUID.generate(),
                 currency_id: Ecto.UUID.generate(),
                 amount: 1,
                 balance_after: 1,
                 type: t
               }).valid?
      end
    end
  end

  describe "UserBalance schema" do
    test "valid user balance changeset" do
      attrs = %{
        user_id: Ecto.UUID.generate(),
        currency_id: Ecto.UUID.generate(),
        balance: 200,
        lifetime_earned: 500
      }

      changeset = UserBalance.changeset(%UserBalance{}, attrs)
      assert changeset.valid?
    end

    test "requires user_id and currency_id" do
      changeset = UserBalance.changeset(%UserBalance{}, %{})
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).user_id
      assert "can't be blank" in errors_on(changeset).currency_id
    end

    test "validates non-negative balance" do
      negative =
        UserBalance.changeset(%UserBalance{}, %{
          user_id: Ecto.UUID.generate(),
          currency_id: Ecto.UUID.generate(),
          balance: -1
        })

      refute negative.valid?
      assert "must be greater than or equal to 0" in errors_on(negative).balance
    end
  end
end
