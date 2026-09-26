defmodule ForgeNexus.EconomyTest do
  use ForgeNexus.DataCase, async: false

  alias ForgeNexus.Accounts
  alias ForgeNexus.Communities
  alias ForgeNexus.Communities.Community
  alias ForgeNexus.Economy

  alias ForgeNexus.Economy.{
    Currency,
    PointConfig,
    PointPack,
    PointTransaction,
    Transaction,
    UserBalance
  }

  defp create_user(attrs \\ %{}) do
    unique = System.unique_integer([:positive])

    default_attrs = %{
      username: "econ_user_#{unique}",
      email: "econ_user_#{unique}@example.com",
      password: "Fn9#xK8$mQ2!wZ7^vL4*",
      display_name: "Econ User #{unique}"
    }

    {:ok, user} = Accounts.register_user(Map.merge(default_attrs, attrs))
    user
  end

  defp create_currency(attrs \\ %{}) do
    unique = System.unique_integer([:positive])

    default_attrs = %{
      name: "Gold Coins #{unique}",
      code: "GLD#{rem(unique, 1000)}",
      symbol: "G",
      slug: "gold-#{unique}",
      is_active: true,
      is_default: false,
      exchange_rate: Decimal.new("1.0")
    }

    {:ok, currency} =
      %Currency{}
      |> Currency.changeset(Map.merge(default_attrs, attrs))
      |> Repo.insert()

    currency
  end

  defp ensure_community do
    case Communities.get_community_by_slug("default") do
      nil ->
        %Community{
          id: Communities.default_community_id(),
          name: "ForgeNexus Default",
          slug: "default",
          subdomain: "default",
          is_active: true
        }
        |> Repo.insert!()

      community ->
        community
    end
  end

  # =========================================================================
  # Legacy Single-Currency Points
  # =========================================================================
  describe "legacy points system" do
    test "get_points/1 returns 0 for non-existent user" do
      assert Economy.get_points(Ecto.UUID.generate()) == 0
    end

    test "award_points/3 with reason awards configured or default rate" do
      user = create_user()
      assert Economy.get_points(user.id) == 0

      assert {:ok, %PointTransaction{} = tx} =
               Economy.award_points(user.id, "post_created",
                 reference_type: "post",
                 reference_id: Ecto.UUID.generate(),
                 description: "Created first post"
               )

      assert tx.amount == 5
      assert tx.balance_after == 5
      assert tx.reason == "post_created"
      assert tx.reference_type == "post"
      assert tx.description == "Created first post"

      assert Economy.get_points(user.id) == 5
    end

    test "award_points/3 with explicit amount awards specified points" do
      user = create_user()

      assert {:ok, %PointTransaction{} = tx} =
               Economy.award_points(user.id, "custom_bonus", amount: 50)

      assert tx.amount == 50
      assert tx.balance_after == 50
      assert Economy.get_points(user.id) == 50
    end

    test "award_points/3 with non-positive amount returns {:ok, :no_points}" do
      user = create_user()
      assert Economy.award_points(user.id, "zero_action", amount: 0) == {:ok, :no_points}
      assert Economy.get_points(user.id) == 0
    end

    test "deduct_points/4 deducts points successfully when balance is sufficient" do
      user = create_user()
      Economy.award_points(user.id, "grant", amount: 100)

      assert {:ok, %PointTransaction{} = tx} =
               Economy.deduct_points(user.id, 40, "shop_purchase", description: "Bought sword")

      assert tx.amount == -40
      assert tx.balance_after == 60
      assert tx.reason == "shop_purchase"
      assert Economy.get_points(user.id) == 60
    end

    test "deduct_points/4 fails with :insufficient_points when balance is too low" do
      user = create_user()
      Economy.award_points(user.id, "grant", amount: 20)

      assert {:error, :insufficient_points} =
               Economy.deduct_points(user.id, 50, "shop_purchase", [])

      assert Economy.get_points(user.id) == 20
    end

    test "deduct_points/3 binary reason delegates to deduct_legacy_points" do
      user = create_user()
      Economy.award_points(user.id, "grant", amount: 30)

      assert {:ok, %PointTransaction{}} = Economy.deduct_points(user.id, 10, "penalty")
      assert Economy.get_points(user.id) == 20
    end

    test "deduct_legacy_points/4 raises ArgumentError on zero or negative amount" do
      user = create_user()

      assert_raise ArgumentError, "amount must be positive", fn ->
        Economy.deduct_legacy_points(user.id, 0, "invalid")
      end

      assert_raise ArgumentError, "amount must be positive", fn ->
        Economy.deduct_legacy_points(user.id, -10, "invalid")
      end
    end

    test "transaction_history/2 returns user point transactions in descending order" do
      user = create_user()
      Economy.award_points(user.id, "tx1", amount: 10)
      Economy.award_points(user.id, "tx2", amount: 20)
      Economy.award_points(user.id, "tx3", amount: 30)

      history = Economy.transaction_history(user.id, limit: 2)
      assert length(history) == 2
      assert hd(history).amount == 30

      full_history = Economy.transaction_history(user.id)
      assert length(full_history) == 3
    end

    test "leaderboard/1 lists users with positive points in descending order" do
      u1 = create_user()
      u2 = create_user()
      u3 = create_user()

      Economy.award_points(u1.id, "seed", amount: 100)
      Economy.award_points(u2.id, "seed", amount: 300)
      Economy.award_points(u3.id, "seed", amount: 200)

      board = Economy.leaderboard(2)
      assert length(board) == 2
      assert hd(board).id == u2.id
      assert hd(board).points == 300
      assert Enum.at(board, 1).id == u3.id
      assert Enum.at(board, 1).points == 200
    end
  end

  # =========================================================================
  # Point Rates & Config
  # =========================================================================
  describe "point rates and config" do
    test "get_rate/1 returns default rate when no config exists" do
      assert Economy.get_rate("post_created") == 5
      assert Economy.get_rate("thread_created") == 10
      assert Economy.get_rate("unknown_action") == 0
    end

    test "update_config/3 creates or updates PointConfig and affects get_rate/1" do
      assert {:ok, %PointConfig{} = cfg} = Economy.update_config("post_created", 20, true)
      assert cfg.points == 20
      assert Economy.get_rate("post_created") == 20

      # Update existing
      assert {:ok, %PointConfig{} = updated} = Economy.update_config("post_created", 35, true)
      assert updated.points == 35
      assert Economy.get_rate("post_created") == 35
    end

    test "list_config/0 merges default rates with database configurations" do
      Economy.update_config("post_created", 15, true)

      configs = Economy.list_config()
      assert is_list(configs)

      post_cfg = Enum.find(configs, &(&1.action == "post_created"))
      assert post_cfg.points == 15
      assert post_cfg.is_default == false

      thread_cfg = Enum.find(configs, &(&1.action == "thread_created"))
      assert thread_cfg.points == 10
      assert thread_cfg.is_default == true
    end
  end

  # =========================================================================
  # Multi-Currency Economy System
  # =========================================================================
  describe "multi-currency system" do
    test "list_currencies/0 and get_default_currency/0" do
      c1 = create_currency(%{name: "Silver", is_default: false})
      c2 = create_currency(%{name: "Gold", is_default: true})

      currencies = Economy.list_currencies()
      assert Enum.any?(currencies, &(&1.id == c1.id))
      assert Enum.any?(currencies, &(&1.id == c2.id))

      default = Economy.get_default_currency()
      assert default != nil
      assert default.is_default == true
    end

    test "get_currency_by_slug/1 finds active currency by slug" do
      c = create_currency(%{slug: "gems-slug"})
      assert Economy.get_currency_by_slug("gems-slug").id == c.id
      assert Economy.get_currency_by_slug("nonexistent") == nil
    end

    test "get_balance/2 returns 0 and creates record if not existing" do
      user = create_user()
      currency = create_currency()

      assert %UserBalance{balance: 0} = Economy.get_balance(user.id, currency.id)

      # Second lookup retrieves existing balance as integer
      assert Economy.get_balance(user.id, currency.id) == 0
    end

    test "award_points/3 multi-currency increases balance and creates transaction" do
      user = create_user()
      currency = create_currency()

      assert {:ok, 250} = Economy.award_points(user.id, currency.id, 250)
      assert Economy.get_balance(user.id, currency.id) == 250

      # Award again
      assert {:ok, 300} = Economy.award_points(user.id, currency.id, 50)
      assert Economy.get_balance(user.id, currency.id) == 300
    end

    test "deduct_points/3 multi-currency deducts when sufficient balance" do
      user = create_user()
      currency = create_currency()

      Economy.award_points(user.id, currency.id, 500)

      assert {:ok, 350} = Economy.deduct_points(user.id, currency.id, 150)
      assert Economy.get_balance(user.id, currency.id) == 350
    end

    test "deduct_points/3 multi-currency returns {:error, :insufficient_balance} when balance is too low" do
      user = create_user()
      currency = create_currency()

      Economy.award_points(user.id, currency.id, 50)

      assert {:error, :insufficient_balance} = Economy.deduct_points(user.id, currency.id, 100)
      assert Economy.get_balance(user.id, currency.id) == 50
    end

    test "transfer_points/4 transfers points between two users" do
      u1 = create_user()
      u2 = create_user()
      currency = create_currency()

      Economy.award_points(u1.id, currency.id, 300)

      assert {:ok, :ok} = Economy.transfer_points(u1.id, u2.id, currency.id, 120)

      assert Economy.get_balance(u1.id, currency.id) == 180
      assert Economy.get_balance(u2.id, currency.id) == 120
    end

    test "transfer_points/4 rolls back when sender has insufficient balance" do
      u1 = create_user()
      u2 = create_user()
      currency = create_currency()

      Economy.award_points(u1.id, currency.id, 40)

      assert {:error, :insufficient_balance} =
               Economy.transfer_points(u1.id, u2.id, currency.id, 100)

      assert Economy.get_balance(u1.id, currency.id) == 40
      bal2 = Economy.get_balance(u2.id, currency.id)
      assert (is_map(bal2) and bal2.balance == 0) or bal2 == 0
    end

    test "get_leaderboard/2 and get_user_rank/2 for currency" do
      u1 = create_user()
      u2 = create_user()
      u3 = create_user()
      currency = create_currency()

      Economy.award_points(u1.id, currency.id, 100)
      Economy.award_points(u2.id, currency.id, 500)
      Economy.award_points(u3.id, currency.id, 300)

      board = Economy.get_leaderboard(currency.id, 2)
      assert length(board) == 2
      assert hd(board).user_id == u2.id
      assert hd(board).balance == 500

      # Rank 1 is u2 (500), Rank 2 is u3 (300), Rank 3 is u1 (100)
      assert Economy.get_user_rank(u2.id, currency.id) == 1
      assert Economy.get_user_rank(u3.id, currency.id) == 2
      assert Economy.get_user_rank(u1.id, currency.id) == 3
    end

    test "create_transaction/1 validates and creates transaction record" do
      user = create_user()
      currency = create_currency()

      assert {:ok, %Transaction{} = tx} =
               Economy.create_transaction(%{
                 user_id: user.id,
                 currency_id: currency.id,
                 amount: 100,
                 balance_after: 100,
                 type: "award"
               })

      assert tx.amount == 100
      assert tx.type == "award"
    end
  end

  # =========================================================================
  # Point Packs & Interest
  # =========================================================================
  describe "point packs and interest" do
    test "create_point_pack/1, get_point_pack!/1, update_point_pack/2, and list_point_packs/1" do
      community = ensure_community()

      attrs = %{
        community_id: community.id,
        name: "Starter Pack",
        points: 500,
        bonus_points: 50,
        price_cents: 499,
        position: 1,
        is_active: true
      }

      assert {:ok, %PointPack{} = pack} = Economy.create_point_pack(attrs)
      assert pack.name == "Starter Pack"

      fetched = Economy.get_point_pack!(pack.id)
      assert fetched.id == pack.id

      assert {:ok, %PointPack{} = updated} =
               Economy.update_point_pack(pack.id, %{bonus_points: 100})

      assert updated.bonus_points == 100

      packs = Economy.list_point_packs(community.id)
      assert Enum.any?(packs, &(&1.id == pack.id))
    end

    test "purchase_point_pack/4 awards points, creates purchase and ledger record" do
      community = ensure_community()
      user = create_user()

      {:ok, pack} =
        Economy.create_point_pack(%{
          community_id: community.id,
          name: "Pro Coin Pack",
          points: 1000,
          bonus_points: 200,
          price_cents: 999,
          position: 2,
          is_active: true
        })

      assert {:ok, purchase} =
               Economy.purchase_point_pack(pack.id, user.id, community.id, "pi_test_stripe_123")

      assert purchase.user_id == user.id
      assert purchase.points_granted == 1200
      assert purchase.amount_cents == 999
      assert purchase.stripe_payment_intent_id == "pi_test_stripe_123"

      # User was awarded 1200 points
      assert Economy.get_points(user.id) == 1200
    end

    test "apply_interest/2 credits percentage interest to all positive balances" do
      currency = create_currency()
      u1 = create_user()
      u2 = create_user()

      Economy.award_points(u1.id, currency.id, 1000)
      Economy.award_points(u2.id, currency.id, 2000)

      # 10% interest
      assert {:ok, 2} = Economy.apply_interest(currency.id, 10)

      # u1 gets 100 -> 1100
      assert Economy.get_balance(u1.id, currency.id) == 1100
      # u2 gets 200 -> 2200
      assert Economy.get_balance(u2.id, currency.id) == 2200
    end

    test "apply_interest/2 rejects invalid rates" do
      currency = create_currency()
      assert Economy.apply_interest(currency.id, 0) == {:error, :invalid_rate}
      assert Economy.apply_interest(currency.id, -5) == {:error, :invalid_rate}
      assert Economy.apply_interest(currency.id, "invalid") == {:error, :invalid_rate}
    end
  end
end
