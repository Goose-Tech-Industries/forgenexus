defmodule ForgeNexus.Plugins.NodesAdminModerationEconomyTest do
  use ForgeNexus.DataCase, async: false

  alias ForgeNexus.Plugins.Engine.Context
  alias ForgeNexus.Repo

  # Economy (12)
  alias ForgeNexus.Plugins.Nodes.Economy.{
    AddInterest,
    AwardPoints,
    CheckBalance,
    CreateLotteryPool,
    CreateTransaction,
    CurrencyExchange,
    DeductPoints,
    GetBalance,
    GetLeaderboard,
    SetPrice,
    TaxTransaction,
    TransferPoints
  }

  # Moderation (10)
  alias ForgeNexus.Plugins.Nodes.Moderation.{
    AddInfraction,
    BulkDelete,
    CheckInfractionPoints,
    IpBan,
    QuarantineUser,
    SendModAlert,
    SetPostApproval,
    SlowMode,
    TimeoutUser,
    UnbanUser
  }

  # User Management (10)
  alias ForgeNexus.Plugins.Nodes.UserManagement.{
    CheckOnlineStatus,
    CheckUserGroup,
    DemoteUser,
    GetUserProfile,
    MergeAccounts,
    PromoteUser,
    SetUserFlair,
    SetUserGroup,
    SetUserTitle,
    SetUsernameStyle
  }

  # Approval (3)
  alias ForgeNexus.Plugins.Nodes.Approval.{
    AutoApproveOnTimeout,
    DelegateApproval,
    MultiLevelApproval
  }

  # Verification (8)
  alias ForgeNexus.Plugins.Nodes.Verification.{
    AssignOnboardingChecklist,
    CheckAccountCriteria,
    CheckOnboardingComplete,
    CreateIntroductionPrompt,
    MentorshipPair,
    SendCaptcha,
    SendVerificationDm,
    VerifyCaptcha
  }

  defp make_ctx(overrides \\ %{}) do
    base = %Context{
      execution_id: Ecto.UUID.generate(),
      flow_id: Ecto.UUID.generate(),
      community_id: Ecto.UUID.generate(),
      started_at: DateTime.utc_now()
    }

    struct(base, overrides)
  end

  defp create_user(attrs \\ %{}) do
    uid = System.unique_integer([:positive])

    {:ok, user} =
      ForgeNexus.Accounts.register_user(%{
        username: "user_#{uid}",
        email: "user_#{uid}@example.com",
        password: "ValidPassword123!@#"
      })

    if attrs == %{} do
      user
    else
      user
      |> Ecto.Changeset.change(attrs)
      |> Repo.update!()
    end
  end

  defp create_currency(attrs) do
    uid = System.unique_integer([:positive])

    %ForgeNexus.Economy.Currency{}
    |> ForgeNexus.Economy.Currency.changeset(
      Map.merge(
        %{
          name: "Currency #{uid}",
          slug: "cur_#{uid}",
          is_active: true,
          is_default: false
        },
        attrs
      )
    )
    |> Repo.insert!()
  end

  defp set_user_balance(user_id, currency_id, balance) do
    case Repo.one(
           from ub in ForgeNexus.Economy.UserBalance,
             where: ub.user_id == ^user_id and ub.currency_id == ^currency_id
         ) do
      nil ->
        %ForgeNexus.Economy.UserBalance{}
        |> ForgeNexus.Economy.UserBalance.changeset(%{
          user_id: user_id,
          currency_id: currency_id,
          balance: balance,
          lifetime_earned: balance
        })
        |> Repo.insert!()

      existing ->
        existing
        |> ForgeNexus.Economy.UserBalance.changeset(%{balance: balance})
        |> Repo.update!()
    end
  end

  defp create_user_group(attrs \\ %{}) do
    uid = System.unique_integer([:positive])

    %ForgeNexus.Accounts.UserGroup{}
    |> ForgeNexus.Accounts.UserGroup.changeset(
      Map.merge(
        %{
          name: "Group #{uid}",
          slug: "group-#{uid}"
        },
        attrs
      )
    )
    |> Repo.insert!()
  end

  defp add_user_to_group(user_id, group_id) do
    %ForgeNexus.Accounts.UserGroupMembership{}
    |> ForgeNexus.Accounts.UserGroupMembership.changeset(%{user_id: user_id, group_id: group_id})
    |> Repo.insert!()
  end

  defp create_forum(attrs \\ %{}) do
    uid = System.unique_integer([:positive])

    cat =
      %ForgeNexus.Forums.Category{}
      |> ForgeNexus.Forums.Category.changeset(%{
        name: "Cat #{uid}",
        slug: "cat-#{uid}",
        position: 0
      })
      |> Repo.insert!()

    %ForgeNexus.Forums.Forum{}
    |> ForgeNexus.Forums.Forum.changeset(
      Map.merge(
        %{
          name: "Forum #{uid}",
          slug: "forum-#{uid}",
          category_id: cat.id,
          position: 0
        },
        attrs
      )
    )
    |> Repo.insert!()
  end

  # =========================================================================
  # 1. Economy Nodes (12)
  # =========================================================================

  describe "Economy nodes" do
    test "GetBalance retrieves balance or returns error on missing currency" do
      user = create_user()
      cur = create_currency(%{slug: "gold"})
      set_user_balance(user.id, cur.id, 150)
      ctx = make_ctx()

      assert %{type: "economy/get_balance"} = GetBalance.schema()
      assert :ok = GetBalance.validate_config(%{})

      {:ok, res, u_ctx} =
        GetBalance.execute(%{"currency_slug" => "gold"}, %{user_id: user.id}, ctx)

      assert res.balance == 150
      assert res.currency_name == cur.name
      assert u_ctx.db_operations > ctx.db_operations

      # String input key
      {:ok, res2, _} =
        GetBalance.execute(%{"currency_slug" => "gold"}, %{"user_id" => user.id}, ctx)

      assert res2.balance == 150

      # Currency not found
      {:error, err, _} =
        GetBalance.execute(%{"currency_slug" => "unknown"}, %{user_id: user.id}, ctx)

      assert err =~ "not found"
    end

    test "CheckBalance branches sufficient / insufficient and validates config" do
      user = create_user()
      cur = create_currency(%{slug: "silver"})
      set_user_balance(user.id, cur.id, 100)
      ctx = make_ctx()

      assert %{type: "economy/check_balance"} = CheckBalance.schema()
      assert :ok = CheckBalance.validate_config(%{"threshold" => 50})
      assert :ok = CheckBalance.validate_config(%{})
      assert {:error, _} = CheckBalance.validate_config(%{"threshold" => "bad"})

      # Sufficient (balance >= threshold)
      {:branch, "sufficient", data, _} =
        CheckBalance.execute(
          %{"currency_slug" => "silver", "threshold" => 50},
          %{user_id: user.id},
          ctx
        )

      assert data.balance == 100

      # Insufficient (balance < threshold) with string threshold
      {:branch, "insufficient", data2, _} =
        CheckBalance.execute(
          %{"currency_slug" => "silver", "threshold" => "150.0"},
          %{"user_id" => user.id},
          ctx
        )

      assert data2.balance == 100

      # Fallback to_number on invalid string threshold & non-number
      {:branch, "sufficient", _, _} =
        CheckBalance.execute(
          %{"currency_slug" => "silver", "threshold" => "not_a_num"},
          %{user_id: user.id},
          ctx
        )

      {:branch, "sufficient", _, _} =
        CheckBalance.execute(
          %{"currency_slug" => "silver", "threshold" => :bad},
          %{user_id: user.id},
          ctx
        )

      # Currency not found
      {:error, err, _} =
        CheckBalance.execute(%{"currency_slug" => "unknown"}, %{user_id: user.id}, ctx)

      assert err =~ "not found"
    end

    test "AwardPoints awards points, handles string amounts and fallbacks" do
      user = create_user()
      _cur = create_currency(%{slug: "gems"})
      ctx = make_ctx()

      assert %{type: "economy/award_points"} = AwardPoints.schema()
      assert :ok = AwardPoints.validate_config(%{})

      # Success with integer amount
      {:ok, res, u_ctx} =
        AwardPoints.execute(%{"currency_slug" => "gems"}, %{user_id: user.id, amount: 50}, ctx)

      assert res.new_balance == 50
      assert res.success == true
      assert u_ctx.db_operations > ctx.db_operations

      # Success with string amount
      {:ok, res2, _} =
        AwardPoints.execute(
          %{"currency_slug" => "gems"},
          %{"user_id" => user.id, "amount" => "25"},
          ctx
        )

      assert res2.new_balance == 75

      # Invalid string amount fallback to 0 -> award_points returns invalid_amount
      {:error, :invalid_amount, _} =
        AwardPoints.execute(
          %{"currency_slug" => "gems"},
          %{user_id: user.id, amount: "bad"},
          ctx
        )

      # Non-number fallback to 0 -> invalid_amount
      {:error, :invalid_amount, _} =
        AwardPoints.execute(
          %{"currency_slug" => "gems"},
          %{user_id: user.id, amount: :bad},
          ctx
        )

      # Currency not found
      {:error, err, _} =
        AwardPoints.execute(%{"currency_slug" => "missing"}, %{user_id: user.id, amount: 10}, ctx)

      assert err =~ "not found"
    end

    test "DeductPoints deducts points, handles insufficient balance and invalid amounts" do
      user = create_user()
      cur = create_currency(%{slug: "coins"})
      set_user_balance(user.id, cur.id, 100)
      ctx = make_ctx()

      assert %{type: "economy/deduct_points"} = DeductPoints.schema()
      assert :ok = DeductPoints.validate_config(%{})

      # Success with numeric amount
      {:ok, res, u_ctx} =
        DeductPoints.execute(
          %{"currency_slug" => "coins"},
          %{user_id: user.id, amount: 40},
          ctx
        )

      assert res.new_balance == 60
      assert res.success == true
      assert u_ctx.db_operations > ctx.db_operations

      # Success with string amount
      {:ok, res2, _} =
        DeductPoints.execute(
          %{"currency_slug" => "coins"},
          %{"user_id" => user.id, "amount" => "20"},
          ctx
        )

      assert res2.new_balance == 40

      # Insufficient balance
      {:error, err_insufficient, _} =
        DeductPoints.execute(
          %{"currency_slug" => "coins"},
          %{user_id: user.id, amount: 500},
          ctx
        )

      assert err_insufficient =~ "Insufficient balance"

      # Invalid amount (0)
      {:error, :invalid_amount, _} =
        DeductPoints.execute(
          %{"currency_slug" => "coins"},
          %{user_id: user.id, amount: 0},
          ctx
        )

      # Invalid string amount fallback to 0
      {:error, :invalid_amount, _} =
        DeductPoints.execute(
          %{"currency_slug" => "coins"},
          %{user_id: user.id, amount: "invalid"},
          ctx
        )

      # Non-number fallback to 0
      {:error, :invalid_amount, _} =
        DeductPoints.execute(
          %{"currency_slug" => "coins"},
          %{user_id: user.id, amount: :bad},
          ctx
        )

      # Currency not found
      {:error, err_missing, _} =
        DeductPoints.execute(
          %{"currency_slug" => "missing"},
          %{user_id: user.id, amount: 10},
          ctx
        )

      assert err_missing =~ "not found"
    end

    test "TransferPoints transfers currency between users and handles errors" do
      sender = create_user()
      receiver = create_user()
      cur = create_currency(%{slug: "credits"})
      set_user_balance(sender.id, cur.id, 100)
      ctx = make_ctx()

      assert %{type: "economy/transfer_points"} = TransferPoints.schema()
      assert :ok = TransferPoints.validate_config(%{})

      # Success with atom inputs
      {:ok, res, u_ctx} =
        TransferPoints.execute(
          %{"currency_slug" => "credits"},
          %{from_user_id: sender.id, to_user_id: receiver.id, amount: 40},
          ctx
        )

      assert res.success == true
      assert u_ctx.db_operations > ctx.db_operations

      # Success with string inputs
      {:ok, res2, _} =
        TransferPoints.execute(
          %{"currency_slug" => "credits"},
          %{
            "from_user_id" => sender.id,
            "to_user_id" => receiver.id,
            "amount" => "20"
          },
          ctx
        )

      assert res2.success == true

      # Insufficient balance
      {:error, err_bal, _} =
        TransferPoints.execute(
          %{"currency_slug" => "credits"},
          %{from_user_id: sender.id, to_user_id: receiver.id, amount: 999},
          ctx
        )

      assert err_bal =~ "Insufficient balance"

      # Invalid amount (0)
      {:error, :invalid_amount, _} =
        TransferPoints.execute(
          %{"currency_slug" => "credits"},
          %{from_user_id: sender.id, to_user_id: receiver.id, amount: 0},
          ctx
        )

      # Fallback string and non-number amount
      {:error, :invalid_amount, _} =
        TransferPoints.execute(
          %{"currency_slug" => "credits"},
          %{from_user_id: sender.id, to_user_id: receiver.id, amount: "bad"},
          ctx
        )

      {:error, :invalid_amount, _} =
        TransferPoints.execute(
          %{"currency_slug" => "credits"},
          %{from_user_id: sender.id, to_user_id: receiver.id, amount: :bad},
          ctx
        )

      # Currency not found
      {:error, err_cur, _} =
        TransferPoints.execute(
          %{"currency_slug" => "missing"},
          %{from_user_id: sender.id, to_user_id: receiver.id, amount: 10},
          ctx
        )

      assert err_cur =~ "not found"
    end

    test "CreateLotteryPool deducts points, records transaction and handles errors" do
      user = create_user()
      cur = create_currency(%{slug: "lotto_cur"})
      set_user_balance(user.id, cur.id, 200)
      ctx = make_ctx()

      assert %{type: "economy/create_lottery_pool"} = CreateLotteryPool.schema()
      assert :ok = CreateLotteryPool.validate_config(%{"pool_key" => "weekly_pool"})
      assert {:error, _} = CreateLotteryPool.validate_config(%{})

      # Success
      {:ok, res, u_ctx} =
        CreateLotteryPool.execute(
          %{"currency_slug" => "lotto_cur", "pool_key" => "weekly_pool"},
          %{user_id: user.id, amount: 50},
          ctx
        )

      assert res.pool_total == 50
      assert res.success == true
      assert u_ctx.db_operations > ctx.db_operations

      # String numeric amount
      {:ok, res_str, _} =
        CreateLotteryPool.execute(
          %{"currency_slug" => "lotto_cur", "pool_key" => "weekly_pool"},
          %{user_id: user.id, amount: "25.0"},
          ctx
        )

      assert res_str.success == true

      # Insufficient balance
      {:error, err_insuf, _} =
        CreateLotteryPool.execute(
          %{"currency_slug" => "lotto_cur", "pool_key" => "weekly_pool"},
          %{user_id: user.id, amount: 1000},
          ctx
        )

      assert err_insuf =~ "Insufficient balance"

      # Invalid amount (0)
      {:error, :invalid_amount, _} =
        CreateLotteryPool.execute(
          %{"currency_slug" => "lotto_cur", "pool_key" => "weekly_pool"},
          %{user_id: user.id, amount: 0},
          ctx
        )

      # String and non-number amount fallback
      {:error, :invalid_amount, _} =
        CreateLotteryPool.execute(
          %{"currency_slug" => "lotto_cur", "pool_key" => "weekly_pool"},
          %{user_id: user.id, amount: "bad"},
          ctx
        )

      {:error, :invalid_amount, _} =
        CreateLotteryPool.execute(
          %{"currency_slug" => "lotto_cur", "pool_key" => "weekly_pool"},
          %{user_id: user.id, amount: :bad},
          ctx
        )

      # Currency not found
      {:error, err_cur, _} =
        CreateLotteryPool.execute(
          %{"currency_slug" => "missing"},
          %{user_id: user.id, amount: 10},
          ctx
        )

      assert err_cur =~ "not found"
    end

    test "CreateTransaction records transaction and handles error changeset" do
      user = create_user()
      _cur = create_currency(%{slug: "tx_cur"})
      ctx = make_ctx()

      assert %{type: "economy/create_transaction"} = CreateTransaction.schema()
      assert :ok = CreateTransaction.validate_config(%{})

      # Success with atom keys
      {:ok, res, u_ctx} =
        CreateTransaction.execute(
          %{"currency_slug" => "tx_cur"},
          %{
            from_user_id: user.id,
            amount: 100,
            transaction_type: "award",
            description: "Quest reward"
          },
          ctx
        )

      assert is_binary(res.transaction_id)
      assert res.success == true
      assert u_ctx.db_operations > ctx.db_operations

      # Success with string keys and to_user_id
      {:ok, res2, _} =
        CreateTransaction.execute(
          %{"currency_slug" => "tx_cur"},
          %{
            "to_user_id" => user.id,
            "amount" => "50",
            "transaction_type" => "deduct",
            "description" => "Shop purchase"
          },
          ctx
        )

      assert res2.success == true

      # Fallback to_number: bad string and non-number
      {:ok, _, _} =
        CreateTransaction.execute(
          %{"currency_slug" => "tx_cur"},
          %{from_user_id: user.id, amount: "bad", transaction_type: "award"},
          ctx
        )

      {:ok, _, _} =
        CreateTransaction.execute(
          %{"currency_slug" => "tx_cur"},
          %{from_user_id: user.id, amount: :bad, transaction_type: "award"},
          ctx
        )

      # Currency not found
      {:error, err_cur, _} =
        CreateTransaction.execute(
          %{"currency_slug" => "missing"},
          %{from_user_id: user.id, amount: 10, transaction_type: "award"},
          ctx
        )

      assert err_cur =~ "not found"

      # Error on transaction changeset (nil user_id)
      {:error, %Ecto.Changeset{}, _} =
        CreateTransaction.execute(
          %{"currency_slug" => "tx_cur"},
          %{from_user_id: nil, to_user_id: nil, amount: 10, transaction_type: "award"},
          ctx
        )
    end

    test "CurrencyExchange exchanges currencies and validates config" do
      user = create_user()
      c1 = create_currency(%{slug: "cur1"})
      _c2 = create_currency(%{slug: "cur2"})
      set_user_balance(user.id, c1.id, 200)
      ctx = make_ctx()

      assert %{type: "economy/currency_exchange"} = CurrencyExchange.schema()

      # Validation tests
      assert :ok =
               CurrencyExchange.validate_config(%{
                 "from_currency" => "c1",
                 "to_currency" => "c2",
                 "rate" => 1.5
               })

      assert {:error, _} =
               CurrencyExchange.validate_config(%{"to_currency" => "c2", "rate" => 1.5})

      assert {:error, _} =
               CurrencyExchange.validate_config(%{"from_currency" => "c1", "rate" => 1.5})

      assert {:error, _} =
               CurrencyExchange.validate_config(%{
                 "from_currency" => "c1",
                 "to_currency" => "c2",
                 "rate" => 0
               })

      assert {:error, _} =
               CurrencyExchange.validate_config(%{
                 "from_currency" => "c1",
                 "to_currency" => "c2",
                 "rate" => "bad"
               })

      assert :ok =
               CurrencyExchange.validate_config(%{
                 "from_currency" => "c1",
                 "to_currency" => "c2"
               })

      # Success
      {:ok, res, u_ctx} =
        CurrencyExchange.execute(
          %{"from_currency" => "cur1", "to_currency" => "cur2", "rate" => 2.0},
          %{user_id: user.id, amount: 50},
          ctx
        )

      assert res.converted_amount == 100.0
      assert res.success == true
      assert u_ctx.db_operations > ctx.db_operations

      # Success with string numeric amount
      {:ok, res_str, _} =
        CurrencyExchange.execute(
          %{"from_currency" => "cur1", "to_currency" => "cur2", "rate" => 2.0},
          %{user_id: user.id, amount: "20.0"},
          ctx
        )

      assert res_str.converted_amount == 40.0

      # Missing source currency
      {:error, err1, _} =
        CurrencyExchange.execute(
          %{"from_currency" => "missing", "to_currency" => "cur2"},
          %{user_id: user.id, amount: 10},
          ctx
        )

      assert err1 =~ "Source currency 'missing' not found"

      # Missing target currency
      {:error, err2, _} =
        CurrencyExchange.execute(
          %{"from_currency" => "cur1", "to_currency" => "missing"},
          %{user_id: user.id, amount: 10},
          ctx
        )

      assert err2 =~ "Target currency 'missing' not found"

      # Insufficient balance
      {:error, err_bal, _} =
        CurrencyExchange.execute(
          %{"from_currency" => "cur1", "to_currency" => "cur2"},
          %{user_id: user.id, amount: 1000},
          ctx
        )

      assert err_bal =~ "Insufficient balance"

      # Invalid amount (0)
      {:error, :invalid_amount, _} =
        CurrencyExchange.execute(
          %{"from_currency" => "cur1", "to_currency" => "cur2"},
          %{user_id: user.id, amount: 0},
          ctx
        )

      # Award error: converted_amount truncates to 0
      {:error, :invalid_amount, _} =
        CurrencyExchange.execute(
          %{"from_currency" => "cur1", "to_currency" => "cur2", "rate" => 0.00001},
          %{user_id: user.id, amount: 1},
          ctx
        )

      # to_number fallbacks
      {:error, :invalid_amount, _} =
        CurrencyExchange.execute(
          %{"from_currency" => "cur1", "to_currency" => "cur2", "rate" => "not_num"},
          %{user_id: user.id, amount: "bad"},
          ctx
        )

      {:error, :invalid_amount, _} =
        CurrencyExchange.execute(
          %{"from_currency" => "cur1", "to_currency" => "cur2", "rate" => :bad},
          %{user_id: user.id, amount: :bad},
          ctx
        )
    end

    test "GetLeaderboard returns entries and handles formatting" do
      user = create_user()
      cur = create_currency(%{slug: "lb_cur"})
      set_user_balance(user.id, cur.id, 500)
      ctx = make_ctx()

      assert %{type: "economy/get_leaderboard"} = GetLeaderboard.schema()
      assert :ok = GetLeaderboard.validate_config(%{})

      # Success with int limit
      {:ok, res, u_ctx} =
        GetLeaderboard.execute(%{"currency_slug" => "lb_cur", "limit" => 5}, %{}, ctx)

      assert is_list(res.entries)
      assert length(res.entries) >= 1
      assert u_ctx.db_operations > ctx.db_operations

      # Success with float limit
      {:ok, res2, _} =
        GetLeaderboard.execute(%{"currency_slug" => "lb_cur", "limit" => 5.0}, %{}, ctx)

      assert length(res2.entries) >= 1

      # Success with string limit
      {:ok, res3, _} =
        GetLeaderboard.execute(%{"currency_slug" => "lb_cur", "limit" => "5"}, %{}, ctx)

      assert length(res3.entries) >= 1

      # Fallback string and non-number limit
      {:ok, res4, _} =
        GetLeaderboard.execute(%{"currency_slug" => "lb_cur", "limit" => "bad"}, %{}, ctx)

      assert length(res4.entries) >= 1

      {:ok, res5, _} =
        GetLeaderboard.execute(%{"currency_slug" => "lb_cur", "limit" => :bad}, %{}, ctx)

      assert length(res5.entries) >= 1

      # Currency not found
      {:error, err, _} =
        GetLeaderboard.execute(%{"currency_slug" => "missing"}, %{}, ctx)

      assert err =~ "not found"
    end

    test "SetPrice records item prices into ctx flow_data" do
      ctx = make_ctx()

      assert %{type: "economy/set_price"} = SetPrice.schema()
      assert :ok = SetPrice.validate_config(%{})

      {:ok, res, u_ctx} =
        SetPrice.execute(
          %{"currency_slug" => "diamonds"},
          %{item_id: "sword_01", price: 250},
          ctx
        )

      assert res.success == true
      assert u_ctx.flow_data["item_prices"]["sword_01"]["price"] == 250
      assert u_ctx.flow_data["item_prices"]["sword_01"]["currency"] == "diamonds"

      # String inputs
      {:ok, _, u_ctx2} =
        SetPrice.execute(
          %{"currency_slug" => "diamonds"},
          %{"item_id" => "shield_01", "price" => 150},
          u_ctx
        )

      assert u_ctx2.flow_data["item_prices"]["shield_01"]["price"] == 150
    end

    test "TaxTransaction applies tax and validates config" do
      user = create_user()
      cur = create_currency(%{slug: "tax_cur"})
      set_user_balance(user.id, cur.id, 500)
      ctx = make_ctx()

      assert %{type: "economy/tax_transaction"} = TaxTransaction.schema()
      assert :ok = TaxTransaction.validate_config(%{"tax_rate_percent" => 10.0})
      assert :ok = TaxTransaction.validate_config(%{})
      assert {:error, _} = TaxTransaction.validate_config(%{"tax_rate_percent" => 150})
      assert {:error, _} = TaxTransaction.validate_config(%{"tax_rate_percent" => -5})
      assert {:error, _} = TaxTransaction.validate_config(%{"tax_rate_percent" => "bad"})

      # Success
      {:ok, res, u_ctx} =
        TaxTransaction.execute(
          %{"currency_slug" => "tax_cur", "tax_rate_percent" => 10.0},
          %{user_id: user.id, amount: 100},
          ctx
        )

      assert res.tax_amount == 10.0
      assert res.net_amount == 90.0
      assert res.success == true
      assert u_ctx.db_operations > ctx.db_operations

      # Success with string numeric amount
      {:ok, res_str, _} =
        TaxTransaction.execute(
          %{"currency_slug" => "tax_cur", "tax_rate_percent" => 10.0},
          %{user_id: user.id, amount: "50.0"},
          ctx
        )

      assert res_str.tax_amount == 5.0

      # Insufficient balance for tax
      {:error, err_bal, _} =
        TaxTransaction.execute(
          %{"currency_slug" => "tax_cur", "tax_rate_percent" => 50.0},
          %{user_id: user.id, amount: 2000},
          ctx
        )

      assert err_bal =~ "Insufficient balance for tax"

      # Invalid amount (0)
      {:error, :invalid_amount, _} =
        TaxTransaction.execute(
          %{"currency_slug" => "tax_cur", "tax_rate_percent" => 10.0},
          %{user_id: user.id, amount: 0},
          ctx
        )

      # String and non-number fallback
      {:error, :invalid_amount, _} =
        TaxTransaction.execute(
          %{"currency_slug" => "tax_cur", "tax_rate_percent" => "bad"},
          %{user_id: user.id, amount: "bad"},
          ctx
        )

      {:error, :invalid_amount, _} =
        TaxTransaction.execute(
          %{"currency_slug" => "tax_cur", "tax_rate_percent" => :bad},
          %{user_id: user.id, amount: :bad},
          ctx
        )

      # Currency not found
      {:error, err_cur, _} =
        TaxTransaction.execute(
          %{"currency_slug" => "missing"},
          %{user_id: user.id, amount: 10},
          ctx
        )

      assert err_cur =~ "not found"
    end

    test "AddInterest applies interest to active balances and validates config" do
      user = create_user()
      cur = create_currency(%{slug: "interest_cur"})
      set_user_balance(user.id, cur.id, 1000)
      ctx = make_ctx()

      assert %{type: "economy/add_interest"} = AddInterest.schema()
      assert :ok = AddInterest.validate_config(%{"rate_percent" => 5.0})
      assert :ok = AddInterest.validate_config(%{})
      assert {:error, _} = AddInterest.validate_config(%{"rate_percent" => -1})
      assert {:error, _} = AddInterest.validate_config(%{"rate_percent" => "bad"})

      # Success with positive rate
      {:ok, res, u_ctx} =
        AddInterest.execute(
          %{"currency_slug" => "interest_cur", "rate_percent" => 5.0},
          %{},
          ctx
        )

      assert res.accounts_updated >= 1
      assert res.total_interest == 0
      assert u_ctx.db_operations > ctx.db_operations

      # Success with string rate
      {:ok, res2, _} =
        AddInterest.execute(
          %{"currency_slug" => "interest_cur", "rate_percent" => "2.5"},
          %{},
          ctx
        )

      assert res2.accounts_updated >= 1

      # Invalid rate (<= 0)
      {:error, :invalid_rate, _} =
        AddInterest.execute(
          %{"currency_slug" => "interest_cur", "rate_percent" => 0.0},
          %{},
          ctx
        )

      # String and non-number fallback to 0.0 -> :invalid_rate
      {:error, :invalid_rate, _} =
        AddInterest.execute(
          %{"currency_slug" => "interest_cur", "rate_percent" => "not_num"},
          %{},
          ctx
        )

      {:error, :invalid_rate, _} =
        AddInterest.execute(
          %{"currency_slug" => "interest_cur", "rate_percent" => :bad},
          %{},
          ctx
        )

      # Currency not found
      {:error, err_cur, _} =
        AddInterest.execute(%{"currency_slug" => "missing"}, %{}, ctx)

      assert err_cur =~ "not found"
    end
  end

  # =========================================================================
  # 2. Moderation Nodes (10)
  # =========================================================================

  describe "Moderation nodes" do
    test "AddInfraction adds warning points and handles errors" do
      user = create_user()
      ctx = make_ctx()

      assert %{type: "moderation/add_infraction"} = AddInfraction.schema()
      assert :ok = AddInfraction.validate_config(%{})

      # Success with integer points
      {:ok, res, u_ctx} =
        AddInfraction.execute(%{}, %{user_id: user.id, points: 5, reason: "Spam"}, ctx)

      assert res.total_points >= 5
      assert res.success == true
      assert u_ctx.db_operations > ctx.db_operations

      # Success with float points and string keys
      {:ok, res2, _} =
        AddInfraction.execute(
          %{},
          %{"user_id" => user.id, "points" => 3.0, "reason" => "Mild spam"},
          ctx
        )

      assert res2.total_points >= 8

      # Error on non-existent user
      {:error, msg, _} =
        AddInfraction.execute(
          %{},
          %{user_id: Ecto.UUID.generate(), points: 10, reason: "Test"},
          ctx
        )

      assert msg =~ "Failed to add infraction"
    end

    test "BulkDelete deletes posts by id" do
      user = create_user()
      forum = create_forum()

      thread =
        %ForgeNexus.Forums.Thread{}
        |> ForgeNexus.Forums.Thread.changeset(%{
          title: "Thread for Bulk Delete",
          slug: "t-#{System.unique_integer([:positive])}",
          forum_id: forum.id,
          user_id: user.id
        })
        |> Repo.insert!()

      post =
        %ForgeNexus.Forums.Post{}
        |> ForgeNexus.Forums.Post.changeset(%{
          body: "Post to delete",
          thread_id: thread.id,
          forum_id: forum.id,
          user_id: user.id
        })
        |> Repo.insert!()

      ctx = make_ctx()

      assert %{type: "moderation/bulk_delete"} = BulkDelete.schema()
      assert :ok = BulkDelete.validate_config(%{})

      {:ok, res, u_ctx} =
        BulkDelete.execute(%{}, %{target_type: "post", target_ids: [post.id]}, ctx)

      assert res.deleted_count == 1
      assert u_ctx.db_operations > ctx.db_operations

      # Other target type
      {:ok, res2, _} =
        BulkDelete.execute(%{}, %{target_type: "other", target_ids: [post.id]}, ctx)

      assert res2.deleted_count == 0

      # Non-list target_ids fallback
      {:ok, res3, _} =
        BulkDelete.execute(%{}, %{target_type: "post", target_ids: "not_a_list"}, ctx)

      assert res3.deleted_count == 0
    end

    test "CheckInfractionPoints branches above / below and validates config" do
      user = create_user()
      ctx = make_ctx()

      assert %{type: "moderation/check_infraction_points"} = CheckInfractionPoints.schema()
      assert :ok = CheckInfractionPoints.validate_config(%{"threshold" => 5})
      assert :ok = CheckInfractionPoints.validate_config(%{"threshold" => "5"})
      assert {:error, _} = CheckInfractionPoints.validate_config(%{"threshold" => nil})
      assert {:error, _} = CheckInfractionPoints.validate_config(%{"threshold" => -1})
      assert {:error, _} = CheckInfractionPoints.validate_config(%{"threshold" => "bad"})
      assert {:error, _} = CheckInfractionPoints.validate_config(%{"threshold" => :bad})

      # Below threshold
      {:branch, "below", %{points: pts}, _} =
        CheckInfractionPoints.execute(%{"threshold" => 10}, %{user_id: user.id}, ctx)

      assert pts == 0

      # Add points and branch above
      {:ok, _, _} =
        AddInfraction.execute(%{}, %{user_id: user.id, points: 15, reason: "Rule breach"}, ctx)

      {:branch, "above", %{points: pts2}, _} =
        CheckInfractionPoints.execute(%{"threshold" => "10.0"}, %{"user_id" => user.id}, ctx)

      assert pts2 >= 15

      # to_number fallbacks: bad string and non-number
      {:branch, "above", _, _} =
        CheckInfractionPoints.execute(%{"threshold" => "not_num"}, %{user_id: user.id}, ctx)

      {:branch, "above", _, _} =
        CheckInfractionPoints.execute(%{"threshold" => :bad}, %{user_id: user.id}, ctx)
    end

    test "IpBan bans an IP address and handles errors" do
      _sys_user = create_user()
      ctx = make_ctx()

      assert %{type: "moderation/ip_ban"} = IpBan.schema()
      assert :ok = IpBan.validate_config(%{})

      # Success with duration_hours integer
      {:ok, res, u_ctx} =
        IpBan.execute(
          %{"duration_hours" => 24},
          %{ip_address: "192.168.1.100", reason: "Abuse"},
          ctx
        )

      assert res.success == true
      assert u_ctx.db_operations > ctx.db_operations

      # Success with float duration_hours and string inputs
      {:ok, res2, _} =
        IpBan.execute(
          %{"duration_hours" => 12.0},
          %{"ip_address" => "192.168.1.101", "reason" => "Abuse"},
          ctx
        )

      assert res2.success == true

      # Success with string duration_hours
      {:ok, res3, _} =
        IpBan.execute(
          %{"duration_hours" => "6"},
          %{ip_address: "192.168.1.102", reason: "Abuse"},
          ctx
        )

      assert res3.success == true

      # Fallback string and non-number duration
      {:ok, res4, _} =
        IpBan.execute(
          %{"duration_hours" => "bad"},
          %{ip_address: "192.168.1.103", reason: "Abuse"},
          ctx
        )

      assert res4.success == true

      {:ok, res5, _} =
        IpBan.execute(
          %{"duration_hours" => :bad},
          %{ip_address: "192.168.1.104", reason: "Abuse"},
          ctx
        )

      assert res5.success == true

      # Error branch (nil reason causes changeset validation failure)
      {:error, msg, _} =
        IpBan.execute(%{}, %{ip_address: "192.168.1.105", reason: nil}, ctx)

      assert msg =~ "Failed to ban IP"
    end

    test "QuarantineUser quarantines a user and handles errors" do
      user = create_user()
      ctx = make_ctx()

      assert %{type: "moderation/quarantine_user"} = QuarantineUser.schema()
      assert :ok = QuarantineUser.validate_config(%{})

      # Success
      {:ok, res, u_ctx} =
        QuarantineUser.execute(%{}, %{user_id: user.id, reason: "Investigation"}, ctx)

      assert res.success == true
      assert u_ctx.db_operations > ctx.db_operations

      # Error on non-existent user
      {:error, msg, _} =
        QuarantineUser.execute(%{}, %{user_id: Ecto.UUID.generate()}, ctx)

      assert msg =~ "Failed to quarantine"
    end

    test "SendModAlert broadcasts alerts with severity fallbacks" do
      ctx = make_ctx()

      assert %{type: "moderation/send_mod_alert"} = SendModAlert.schema()
      assert :ok = SendModAlert.validate_config(%{})

      # Valid severity
      {:ok, res, _} =
        SendModAlert.execute(
          %{},
          %{title: "Alert", description: "Details", severity: "warning", metadata: %{}},
          ctx
        )

      assert res.success == true

      # Invalid severity falls back to "info"
      {:ok, res2, _} =
        SendModAlert.execute(
          %{},
          %{"title" => "Alert 2", "description" => "Details", "severity" => "critical_bad"},
          ctx
        )

      assert res2.success == true
    end

    test "SetPostApproval sets approval requirement on forum and user" do
      forum = create_forum()
      user = create_user()
      ctx = make_ctx()

      assert %{type: "moderation/set_post_approval"} = SetPostApproval.schema()
      assert :ok = SetPostApproval.validate_config(%{})

      # Forum target
      {:ok, res, u_ctx} =
        SetPostApproval.execute(
          %{},
          %{target_type: "forum", target_id: forum.id, require_approval: true},
          ctx
        )

      assert res.success == true
      assert u_ctx.db_operations > ctx.db_operations

      # User target
      {:ok, res2, _} =
        SetPostApproval.execute(
          %{},
          %{"target_type" => "user", "target_id" => user.id, "require_approval" => false},
          ctx
        )

      assert res2.success == true

      # Error (target not found)
      {:error, msg, _} =
        SetPostApproval.execute(
          %{},
          %{target_type: "forum", target_id: Ecto.UUID.generate()},
          ctx
        )

      assert msg =~ "Failed to set post approval"
    end

    test "SlowMode sets forum slow mode delay and handles errors" do
      forum = create_forum()
      ctx = make_ctx()

      assert %{type: "moderation/slow_mode"} = SlowMode.schema()
      assert :ok = SlowMode.validate_config(%{})

      # Success with integer seconds
      {:ok, res, u_ctx} =
        SlowMode.execute(%{}, %{forum_id: forum.id, seconds: 30}, ctx)

      assert res.success == true
      assert u_ctx.db_operations > ctx.db_operations

      # Success with float seconds and string keys
      {:ok, res2, _} =
        SlowMode.execute(%{}, %{"forum_id" => forum.id, "seconds" => 15.0}, ctx)

      assert res2.success == true

      # Error (forum_id not found)
      {:error, msg, _} =
        SlowMode.execute(%{}, %{forum_id: Ecto.UUID.generate(), seconds: 10}, ctx)

      assert msg =~ "Failed to set slow mode"

      # Error (missing forum_id)
      {:error, msg2, _} =
        SlowMode.execute(%{}, %{forum_id: nil, seconds: 10}, ctx)

      assert msg2 =~ "forum_id is required"
    end

    test "TimeoutUser times out a user and handles errors" do
      user = create_user()
      ctx = make_ctx()

      assert %{type: "moderation/timeout_user"} = TimeoutUser.schema()
      assert :ok = TimeoutUser.validate_config(%{})

      # Success with integer duration
      {:ok, res, u_ctx} =
        TimeoutUser.execute(
          %{},
          %{user_id: user.id, duration_seconds: 3600, reason: "Spam"},
          ctx
        )

      assert res.success == true
      assert u_ctx.db_operations > ctx.db_operations

      # Success with float duration
      {:ok, res2, _} =
        TimeoutUser.execute(
          %{},
          %{"user_id" => user.id, "duration_seconds" => 1800.0, "reason" => "Spam"},
          ctx
        )

      assert res2.success == true

      # Error on non-existent user
      {:error, msg, _} =
        TimeoutUser.execute(
          %{},
          %{user_id: Ecto.UUID.generate(), duration_seconds: 60},
          ctx
        )

      assert msg =~ "Failed to timeout user"
    end

    test "UnbanUser lifts ban and handles missing user_id" do
      user = create_user()
      ctx = make_ctx()

      assert %{type: "moderation/unban_user"} = UnbanUser.schema()
      assert :ok = UnbanUser.validate_config(%{})

      # Success (when not banned or banned)
      {:ok, res, u_ctx} =
        UnbanUser.execute(%{}, %{user_id: user.id}, ctx)

      assert res.success == true
      assert u_ctx.db_operations > ctx.db_operations

      # Error (nil user_id)
      {:error, msg, _} =
        UnbanUser.execute(%{}, %{user_id: nil}, ctx)

      assert msg =~ "user_id is required"
    end
  end

  # =========================================================================
  # 3. User Management Nodes (10)
  # =========================================================================

  describe "User Management nodes" do
    test "CheckOnlineStatus branches online / offline" do
      online_user =
        create_user(%{
          is_online: true,
          last_seen_at: DateTime.utc_now() |> DateTime.truncate(:second)
        })

      ten_mins_ago =
        DateTime.utc_now() |> DateTime.add(-600, :second) |> DateTime.truncate(:second)

      offline_user = create_user(%{is_online: false, last_seen_at: ten_mins_ago})
      never_user = create_user(%{is_online: false, last_seen_at: nil})
      ctx = make_ctx()

      assert %{type: "user_management/check_online_status"} = CheckOnlineStatus.schema()
      assert :ok = CheckOnlineStatus.validate_config(%{})

      # Online
      {:branch, "online", %{last_seen_at: _}, u_ctx} =
        CheckOnlineStatus.execute(%{}, %{user_id: online_user.id}, ctx)

      assert u_ctx.db_operations > ctx.db_operations

      # Offline (> 5 min)
      {:branch, "offline", %{last_seen_at: _}, _} =
        CheckOnlineStatus.execute(%{}, %{"user_id" => offline_user.id}, ctx)

      # Offline (never)
      {:branch, "offline", %{last_seen_at: "never"}, _} =
        CheckOnlineStatus.execute(%{}, %{user_id: never_user.id}, ctx)

      # User not found
      {:error, err, _} =
        CheckOnlineStatus.execute(%{}, %{user_id: Ecto.UUID.generate()}, ctx)

      assert err =~ "User not found"
    end

    test "CheckUserGroup branches member / not_member and validates config" do
      user = create_user()
      group = create_user_group()
      add_user_to_group(user.id, group.id)
      ctx = make_ctx()

      assert %{type: "user_management/check_user_group"} = CheckUserGroup.schema()
      assert :ok = CheckUserGroup.validate_config(%{"group_id" => group.id})
      assert {:error, _} = CheckUserGroup.validate_config(%{})

      # Member
      {:branch, "member", %{user_groups: grps}, u_ctx} =
        CheckUserGroup.execute(%{"group_id" => group.id}, %{user_id: user.id}, ctx)

      assert to_string(group.id) in grps
      assert u_ctx.db_operations > ctx.db_operations

      # Not member
      other_group = create_user_group()

      {:branch, "not_member", _, _} =
        CheckUserGroup.execute(%{"group_id" => other_group.id}, %{"user_id" => user.id}, ctx)

      # User not found
      {:error, err, _} =
        CheckUserGroup.execute(%{"group_id" => group.id}, %{user_id: Ecto.UUID.generate()}, ctx)

      assert err =~ "User not found"
    end

    test "DemoteUser updates primary_group_id and validates config" do
      user = create_user()
      target_group = create_user_group()
      ctx = make_ctx()

      assert %{type: "user_management/demote_user"} = DemoteUser.schema()
      assert :ok = DemoteUser.validate_config(%{"target_group_id" => target_group.id})
      assert {:error, _} = DemoteUser.validate_config(%{})

      # Success
      {:ok, res, u_ctx} =
        DemoteUser.execute(%{"target_group_id" => target_group.id}, %{user_id: user.id}, ctx)

      assert res.success == true
      assert res.new_group == to_string(target_group.id)
      assert u_ctx.db_operations > ctx.db_operations

      # String user_id
      {:ok, res2, _} =
        DemoteUser.execute(
          %{"target_group_id" => target_group.id},
          %{"user_id" => user.id},
          ctx
        )

      assert res2.success == true

      # User not found
      {:error, err, _} =
        DemoteUser.execute(
          %{"target_group_id" => target_group.id},
          %{user_id: Ecto.UUID.generate()},
          ctx
        )

      assert err =~ "User not found"
    end

    test "PromoteUser updates primary_group_id and validates config" do
      user = create_user()
      target_group = create_user_group()
      ctx = make_ctx()

      assert %{type: "user_management/promote_user"} = PromoteUser.schema()
      assert :ok = PromoteUser.validate_config(%{"target_group_id" => target_group.id})
      assert {:error, _} = PromoteUser.validate_config(%{})

      # Success
      {:ok, res, u_ctx} =
        PromoteUser.execute(%{"target_group_id" => target_group.id}, %{user_id: user.id}, ctx)

      assert res.success == true
      assert res.new_group == to_string(target_group.id)
      assert u_ctx.db_operations > ctx.db_operations

      # User not found
      {:error, err, _} =
        PromoteUser.execute(
          %{"target_group_id" => target_group.id},
          %{user_id: Ecto.UUID.generate()},
          ctx
        )

      assert err =~ "User not found"
    end

    test "SetUserGroup changes group assignment and returns previous group" do
      group1 = create_user_group()
      group2 = create_user_group()
      user = create_user(%{primary_group_id: group1.id})
      ctx = make_ctx()

      assert %{type: "user_management/set_user_group"} = SetUserGroup.schema()
      assert :ok = SetUserGroup.validate_config(%{})

      # Success
      {:ok, res, u_ctx} =
        SetUserGroup.execute(%{}, %{user_id: user.id, group_id: group2.id}, ctx)

      assert res.success == true
      assert res.previous_group == to_string(group1.id)
      assert u_ctx.db_operations > ctx.db_operations

      # String keys
      {:ok, res2, _} =
        SetUserGroup.execute(
          %{},
          %{"user_id" => user.id, "group_id" => group1.id},
          ctx
        )

      assert res2.success == true

      # User not found
      {:error, err, _} =
        SetUserGroup.execute(%{}, %{user_id: Ecto.UUID.generate(), group_id: group2.id}, ctx)

      assert err =~ "User not found"
    end

    test "GetUserProfile retrieves full user profile" do
      group = create_user_group()
      user = create_user(%{custom_title: "Elder", trust_level: 2})
      add_user_to_group(user.id, group.id)
      ctx = make_ctx()

      assert %{type: "user_management/get_user_profile"} = GetUserProfile.schema()
      assert :ok = GetUserProfile.validate_config(%{})

      # Success with atom keys
      {:ok, res, u_ctx} =
        GetUserProfile.execute(%{}, %{user_id: user.id}, ctx)

      assert res.user.username == user.username
      assert res.user.custom_title == "Elder"
      assert res.user.trust_level == 2
      assert to_string(group.id) in res.user.groups
      assert u_ctx.db_operations > ctx.db_operations

      # Success with string keys
      {:ok, res2, _} =
        GetUserProfile.execute(%{}, %{"user_id" => user.id}, ctx)

      assert res2.user.username == user.username

      # User not found
      {:error, err, _} =
        GetUserProfile.execute(%{}, %{user_id: Ecto.UUID.generate()}, ctx)

      assert err =~ "User not found"
    end

    test "SetUserTitle updates custom display title" do
      user = create_user()
      ctx = make_ctx()

      assert %{type: "user_management/set_user_title"} = SetUserTitle.schema()
      assert :ok = SetUserTitle.validate_config(%{})

      # Success with atom keys
      {:ok, res, u_ctx} =
        SetUserTitle.execute(%{}, %{user_id: user.id, title: "Champion"}, ctx)

      assert res.success == true
      assert u_ctx.db_operations > ctx.db_operations

      # Success with string keys
      {:ok, res2, _} =
        SetUserTitle.execute(%{}, %{"user_id" => user.id, "title" => "Legend"}, ctx)

      assert res2.success == true

      # User not found
      {:error, err, _} =
        SetUserTitle.execute(%{}, %{user_id: Ecto.UUID.generate(), title: "Ghost"}, ctx)

      assert err =~ "User not found"
    end

    test "SetUserFlair updates user flair text and color" do
      user = create_user()
      ctx = make_ctx()

      assert %{type: "user_management/set_user_flair"} = SetUserFlair.schema()
      assert :ok = SetUserFlair.validate_config(%{})

      # Success with atom keys
      {:ok, res, u_ctx} =
        SetUserFlair.execute(
          %{"flair_text" => "VIP", "flair_color" => "#FFD700"},
          %{user_id: user.id},
          ctx
        )

      assert res.success == true
      assert u_ctx.db_operations > ctx.db_operations

      # Success with string keys
      {:ok, res2, _} =
        SetUserFlair.execute(
          %{"flair_text" => "PRO", "flair_color" => "#00FF00"},
          %{"user_id" => user.id},
          ctx
        )

      assert res2.success == true

      # User not found
      {:error, err, _} =
        SetUserFlair.execute(%{}, %{user_id: Ecto.UUID.generate()}, ctx)

      assert err =~ "User not found"
    end

    test "SetUsernameStyle updates username color and effect and validates config" do
      user = create_user()
      ctx = make_ctx()

      assert %{type: "user_management/set_username_style"} = SetUsernameStyle.schema()
      assert :ok = SetUsernameStyle.validate_config(%{"effect" => "glow"})
      assert :ok = SetUsernameStyle.validate_config(%{})
      assert {:error, _} = SetUsernameStyle.validate_config(%{"effect" => "laser"})

      # Success with atom keys
      {:ok, res, u_ctx} =
        SetUsernameStyle.execute(
          %{"color" => "#FF0000", "effect" => "bold"},
          %{user_id: user.id},
          ctx
        )

      assert res.success == true
      assert u_ctx.db_operations > ctx.db_operations

      # Success with string keys
      {:ok, res2, _} =
        SetUsernameStyle.execute(
          %{"color" => "#0000FF", "effect" => "rainbow"},
          %{"user_id" => user.id},
          ctx
        )

      assert res2.success == true

      # User not found
      {:error, err, _} =
        SetUsernameStyle.execute(%{}, %{user_id: Ecto.UUID.generate()}, ctx)

      assert err =~ "User not found"
    end

    test "MergeAccounts reassigns posts and marks secondary user as merged" do
      primary = create_user()
      secondary = create_user()
      forum = create_forum()

      thread =
        %ForgeNexus.Forums.Thread{}
        |> ForgeNexus.Forums.Thread.changeset(%{
          title: "Sec Thread",
          slug: "sec-thread-#{System.unique_integer([:positive])}",
          forum_id: forum.id,
          user_id: secondary.id
        })
        |> Repo.insert!()

      _post =
        %ForgeNexus.Forums.Post{}
        |> ForgeNexus.Forums.Post.changeset(%{
          body: "Sec Post",
          thread_id: thread.id,
          forum_id: forum.id,
          user_id: secondary.id
        })
        |> Repo.insert!()

      ctx = make_ctx()

      assert %{type: "user_management/merge_accounts"} = MergeAccounts.schema()
      assert :ok = MergeAccounts.validate_config(%{})

      # Error when primary == secondary
      {:error, same_err, _} =
        MergeAccounts.execute(
          %{},
          %{primary_user_id: primary.id, secondary_user_id: primary.id},
          ctx
        )

      assert same_err =~ "must differ"

      # Success with existing secondary user
      {:ok, res, u_ctx} =
        MergeAccounts.execute(
          %{},
          %{primary_user_id: primary.id, secondary_user_id: secondary.id},
          ctx
        )

      assert res.success == true
      assert res.merged_post_count == 1
      assert u_ctx.db_operations > ctx.db_operations

      # Success when secondary user is not in User table (nil user path)
      non_existent = Ecto.UUID.generate()

      {:ok, res2, _} =
        MergeAccounts.execute(
          %{},
          %{"primary_user_id" => primary.id, "secondary_user_id" => non_existent},
          ctx
        )

      assert res2.success == true
      assert res2.merged_post_count == 0
    end
  end

  # =========================================================================
  # 4. Approval Nodes (3)
  # =========================================================================

  describe "Approval nodes" do
    test "MultiLevelApproval creates approval request and validates config" do
      ctx = make_ctx()

      assert %{type: "approval/multi_level_approval"} = MultiLevelApproval.schema()

      # Validation tests
      assert :ok = MultiLevelApproval.validate_config(%{"approver_levels" => ["lead", "admin"]})

      assert :ok =
               MultiLevelApproval.validate_config(%{"approver_levels" => "[\"lead\", \"admin\"]"})

      assert {:error, _} = MultiLevelApproval.validate_config(%{"approver_levels" => "bad_json"})
      assert {:error, _} = MultiLevelApproval.validate_config(%{"approver_levels" => nil})
      assert {:error, _} = MultiLevelApproval.validate_config(%{"approver_levels" => 123})

      # Execute with list levels
      {:ok, res1, u_ctx1} =
        MultiLevelApproval.execute(
          %{"approver_levels" => ["lead", "admin"]},
          %{request_id: "req_01", request_data: %{"amount" => 500}},
          ctx
        )

      assert is_binary(res1.approval_id)
      assert res1.current_level == 1
      assert res1.success == true
      assert u_ctx1.db_operations > ctx.db_operations
      assert Map.has_key?(u_ctx1.flow_data["approvals"], res1.approval_id)

      # Execute with JSON string levels
      {:ok, res2, _u_ctx2} =
        MultiLevelApproval.execute(
          %{"approver_levels" => "[\"manager\"]"},
          %{"request_id" => "req_02", "request_data" => %{}},
          ctx
        )

      assert res2.success == true

      # Execute with invalid JSON string fallback
      {:ok, res3, _} =
        MultiLevelApproval.execute(
          %{"approver_levels" => "invalid_json"},
          %{request_id: "req_03"},
          ctx
        )

      assert res3.success == true

      # Execute with non-list/non-string fallback
      {:ok, res4, _} =
        MultiLevelApproval.execute(
          %{"approver_levels" => 999},
          %{request_id: "req_04"},
          ctx
        )

      assert res4.success == true
    end

    test "AutoApproveOnTimeout auto-approves or maintains status and validates config" do
      ctx = make_ctx()

      assert %{type: "approval/auto_approve_on_timeout"} = AutoApproveOnTimeout.schema()
      assert :ok = AutoApproveOnTimeout.validate_config(%{"timeout_hours" => 24})
      assert :ok = AutoApproveOnTimeout.validate_config(%{"timeout_hours" => "24.0"})
      assert :ok = AutoApproveOnTimeout.validate_config(%{})
      assert {:error, _} = AutoApproveOnTimeout.validate_config(%{"timeout_hours" => -5})
      assert {:error, _} = AutoApproveOnTimeout.validate_config(%{"timeout_hours" => "bad"})
      assert {:error, _} = AutoApproveOnTimeout.validate_config(%{"timeout_hours" => :bad})

      # Non-existent approval
      {:ok, res1, _} =
        AutoApproveOnTimeout.execute(%{"timeout_hours" => 24}, %{approval_id: "unknown"}, ctx)

      assert res1.was_auto_approved == false
      assert res1.hours_elapsed == 0.0

      # Approval expired (> 48 hours ago)
      two_days_ago =
        DateTime.utc_now() |> DateTime.add(-180_000, :second) |> DateTime.to_iso8601()

      ctx_with_approval =
        Map.put(ctx, :flow_data, %{
          "approvals" => %{
            "app_old" => %{
              "id" => "app_old",
              "status" => "pending",
              "created_at" => two_days_ago
            }
          }
        })

      {:ok, res2, u_ctx2} =
        AutoApproveOnTimeout.execute(
          %{"timeout_hours" => 48},
          %{"approval_id" => "app_old"},
          ctx_with_approval
        )

      assert res2.was_auto_approved == true
      assert res2.hours_elapsed >= 48.0
      assert u_ctx2.flow_data["approvals"]["app_old"]["status"] == "auto_approved"

      # String numeric timeout_hours in execute
      {:ok, res_str, _} =
        AutoApproveOnTimeout.execute(
          %{"timeout_hours" => "48.0"},
          %{"approval_id" => "app_old"},
          ctx_with_approval
        )

      assert res_str.was_auto_approved == true

      # Approval not expired (< 48 hours ago)
      one_hour_ago = DateTime.utc_now() |> DateTime.add(-3600, :second) |> DateTime.to_iso8601()

      ctx_fresh =
        Map.put(ctx, :flow_data, %{
          "approvals" => %{
            "app_fresh" => %{
              "id" => "app_fresh",
              "status" => "pending",
              "created_at" => one_hour_ago
            }
          }
        })

      {:ok, res3, _} =
        AutoApproveOnTimeout.execute(
          %{"timeout_hours" => 48},
          %{approval_id: "app_fresh"},
          ctx_fresh
        )

      assert res3.was_auto_approved == false

      # Approval with invalid/nil created_at
      ctx_invalid_date =
        Map.put(ctx, :flow_data, %{
          "approvals" => %{
            "app_bad_date" => %{
              "id" => "app_bad_date",
              "status" => "pending",
              "created_at" => nil
            }
          }
        })

      {:ok, res4, _} =
        AutoApproveOnTimeout.execute(
          %{"timeout_hours" => 48},
          %{approval_id: "app_bad_date"},
          ctx_invalid_date
        )

      assert res4.was_auto_approved == false
      assert res4.hours_elapsed == 0.0

      # to_number fallbacks: bad string and non-number
      {:ok, _, _} =
        AutoApproveOnTimeout.execute(
          %{"timeout_hours" => "bad_str"},
          %{approval_id: "app_fresh"},
          ctx_fresh
        )

      {:ok, _, _} =
        AutoApproveOnTimeout.execute(
          %{"timeout_hours" => :bad},
          %{approval_id: "app_fresh"},
          ctx_fresh
        )
    end

    test "DelegateApproval reassigns approval to a new approver" do
      ctx = make_ctx()

      assert %{type: "approval/delegate_approval"} = DelegateApproval.schema()
      assert :ok = DelegateApproval.validate_config(%{})

      ctx_with_app =
        Map.put(ctx, :flow_data, %{
          "approvals" => %{
            "app_01" => %{"id" => "app_01", "delegated_to" => nil}
          }
        })

      # Success
      {:ok, res, u_ctx} =
        DelegateApproval.execute(
          %{},
          %{approval_id: "app_01", new_approver_id: "staff_99"},
          ctx_with_app
        )

      assert res.success == true
      assert u_ctx.flow_data["approvals"]["app_01"]["delegated_to"] == "staff_99"

      # String inputs
      {:ok, res2, _} =
        DelegateApproval.execute(
          %{},
          %{"approval_id" => "app_01", "new_approver_id" => "staff_100"},
          ctx_with_app
        )

      assert res2.success == true

      # Approval not found
      {:error, err, _} =
        DelegateApproval.execute(
          %{},
          %{approval_id: "unknown", new_approver_id: "staff_99"},
          ctx_with_app
        )

      assert err =~ "Approval not found"
    end
  end

  # =========================================================================
  # 5. Verification Nodes (8)
  # =========================================================================

  describe "Verification nodes" do
    test "AssignOnboardingChecklist assigns tasks and validates config" do
      user = create_user()
      ctx = make_ctx()

      assert %{type: "verification/assign_onboarding_checklist"} =
               AssignOnboardingChecklist.schema()

      assert :ok =
               AssignOnboardingChecklist.validate_config(%{
                 "tasks" => ["avatar_upload", "intro_post"]
               })

      assert :ok =
               AssignOnboardingChecklist.validate_config(%{
                 "tasks" => "[\"avatar_upload\", \"intro_post\"]"
               })

      assert {:error, _} = AssignOnboardingChecklist.validate_config(%{"tasks" => "bad_json"})
      assert {:error, _} = AssignOnboardingChecklist.validate_config(%{"tasks" => nil})
      assert {:error, _} = AssignOnboardingChecklist.validate_config(%{"tasks" => 123})

      # Success with list tasks
      {:ok, res1, u_ctx1} =
        AssignOnboardingChecklist.execute(
          %{"tasks" => ["avatar_upload", "intro_post"]},
          %{user_id: user.id},
          ctx
        )

      assert is_binary(res1.checklist_id)
      assert res1.success == true
      assert u_ctx1.db_operations > ctx.db_operations

      # Duplicate assignment causes unique_constraint failure on user_id
      {:error, msg, _} =
        AssignOnboardingChecklist.execute(
          %{"tasks" => ["avatar_upload"]},
          %{user_id: user.id},
          ctx
        )

      assert msg =~ "Failed to assign checklist"

      # Success with JSON string tasks for fresh user
      user2 = create_user()

      {:ok, res2, _} =
        AssignOnboardingChecklist.execute(
          %{"tasks" => "[\"profile_fill\"]"},
          %{"user_id" => user2.id},
          ctx
        )

      assert res2.success == true

      # Fallback tasks: invalid JSON string & non-list/non-string
      user3 = create_user()

      {:ok, res3, _} =
        AssignOnboardingChecklist.execute(
          %{"tasks" => "invalid_json"},
          %{user_id: user3.id},
          ctx
        )

      assert res3.success == true

      user4 = create_user()

      {:ok, res4, _} =
        AssignOnboardingChecklist.execute(
          %{"tasks" => 999},
          %{user_id: user4.id},
          ctx
        )

      assert res4.success == true
    end

    test "CheckAccountCriteria evaluates user age, posts, bio and avatar" do
      user =
        create_user(%{
          avatar_url: "https://example.com/avatar.png",
          bio: "Developer and gamer",
          post_count: 10
        })

      ctx = make_ctx()

      assert %{type: "verification/check_account_criteria"} = CheckAccountCriteria.schema()
      assert :ok = CheckAccountCriteria.validate_config(%{})

      # Passed
      {:branch, "passed", %{criteria_results: results}, u_ctx} =
        CheckAccountCriteria.execute(
          %{
            "min_age_days" => 0,
            "min_posts" => 5,
            "require_avatar" => true,
            "require_bio" => true
          },
          %{user_id: user.id},
          ctx
        )

      assert results["min_posts"].passed == true
      assert u_ctx.db_operations > ctx.db_operations

      # Failed (requires 100 days old)
      {:branch, "failed", %{criteria_results: failed_results}, _} =
        CheckAccountCriteria.execute(
          %{"min_age_days" => "100.0", "min_posts" => "50"},
          %{"user_id" => user.id},
          ctx
        )

      assert failed_results["min_age_days"].passed == false

      # to_number fallbacks: bad string and non-number
      {:branch, "passed", _, _} =
        CheckAccountCriteria.execute(
          %{"min_age_days" => "bad", "min_posts" => :bad},
          %{user_id: user.id},
          ctx
        )

      # User not found
      {:error, err, _} =
        CheckAccountCriteria.execute(%{}, %{user_id: Ecto.UUID.generate()}, ctx)

      assert err =~ "Failed to check account criteria"
    end

    test "CheckOnboardingComplete branches complete / incomplete" do
      user_no_checklist = create_user()
      ctx = make_ctx()

      assert %{type: "verification/check_onboarding_complete"} = CheckOnboardingComplete.schema()
      assert :ok = CheckOnboardingComplete.validate_config(%{})

      # No checklist
      {:branch, "incomplete", %{completed_count: 0, total_count: 0}, u_ctx} =
        CheckOnboardingComplete.execute(%{}, %{user_id: user_no_checklist.id}, ctx)

      assert u_ctx.db_operations > ctx.db_operations

      # Incomplete checklist
      user_partial = create_user()

      %ForgeNexus.Verification.OnboardingChecklist{}
      |> ForgeNexus.Verification.OnboardingChecklist.changeset(%{
        user_id: user_partial.id,
        checklist_data: %{
          "tasks" => [
            %{"key" => "task1", "completed" => true},
            %{"key" => "task2", "completed" => false}
          ]
        },
        completed_count: 1,
        total_count: 2
      })
      |> Repo.insert!()

      {:branch, "incomplete", %{completed_count: 1, total_count: 2}, _} =
        CheckOnboardingComplete.execute(%{}, %{"user_id" => user_partial.id}, ctx)

      # Complete checklist (with atom completed keys as well)
      user_done = create_user()

      %ForgeNexus.Verification.OnboardingChecklist{}
      |> ForgeNexus.Verification.OnboardingChecklist.changeset(%{
        user_id: user_done.id,
        checklist_data: %{
          "tasks" => [
            %{key: "task1", completed: true},
            %{"key" => "task2", "completed" => true}
          ]
        },
        completed_count: 2,
        total_count: 2
      })
      |> Repo.insert!()

      {:branch, "complete", %{completed_count: 2, total_count: 2}, _} =
        CheckOnboardingComplete.execute(%{}, %{user_id: user_done.id}, ctx)

      # Checklist without tasks list (fallback _ -> [])
      user_empty = create_user()

      %ForgeNexus.Verification.OnboardingChecklist{}
      |> ForgeNexus.Verification.OnboardingChecklist.changeset(%{
        user_id: user_empty.id,
        checklist_data: %{"tasks" => "not_a_list"}
      })
      |> Repo.insert!()

      {:branch, "incomplete", %{completed_count: 0, total_count: 0}, _} =
        CheckOnboardingComplete.execute(%{}, %{user_id: user_empty.id}, ctx)
    end

    test "CreateIntroductionPrompt creates intro thread and post in forum" do
      user = create_user()
      forum = create_forum(%{slug: "introductions"})
      ctx = make_ctx()

      assert %{type: "verification/create_introduction_prompt"} =
               CreateIntroductionPrompt.schema()

      assert :ok = CreateIntroductionPrompt.validate_config(%{})

      # Success with atom keys
      {:ok, res, u_ctx} =
        CreateIntroductionPrompt.execute(
          %{"intro_forum_slug" => forum.slug, "template" => "Hello everyone!"},
          %{user_id: user.id},
          ctx
        )

      assert is_binary(res.thread_id)
      assert res.success == true
      assert u_ctx.db_operations > ctx.db_operations

      # Success with string keys
      {:ok, res2, _} =
        CreateIntroductionPrompt.execute(
          %{"intro_forum_slug" => forum.slug},
          %{"user_id" => user.id},
          ctx
        )

      assert res2.success == true

      # Forum not found
      {:ok, res_missing, _} =
        CreateIntroductionPrompt.execute(
          %{"intro_forum_slug" => "non_existent_forum"},
          %{user_id: user.id},
          ctx
        )

      assert res_missing.thread_id == nil
      assert res_missing.success == false

      # Thread creation failure (nil user_id)
      {:error, msg, _} =
        CreateIntroductionPrompt.execute(
          %{"intro_forum_slug" => forum.slug},
          %{user_id: nil},
          ctx
        )

      assert msg =~ "Failed to create intro thread"
    end

    test "MentorshipPair pairs new user with group member and validates config" do
      new_user = create_user()
      mentor = create_user()
      mentor_group = create_user_group()
      add_user_to_group(mentor.id, mentor_group.id)
      ctx = make_ctx()

      assert %{type: "verification/mentorship_pair"} = MentorshipPair.schema()
      assert :ok = MentorshipPair.validate_config(%{"mentor_group_id" => mentor_group.id})
      assert {:error, _} = MentorshipPair.validate_config(%{"mentor_group_id" => ""})
      assert {:error, _} = MentorshipPair.validate_config(%{})

      # Success
      {:ok, res, u_ctx} =
        MentorshipPair.execute(
          %{"mentor_group_id" => mentor_group.id},
          %{new_user_id: new_user.id},
          ctx
        )

      assert res.mentor_user_id == mentor.id
      assert res.success == true
      assert u_ctx.db_operations > ctx.db_operations

      # Success with string inputs
      {:ok, res2, _} =
        MentorshipPair.execute(
          %{"mentor_group_id" => mentor_group.id},
          %{"new_user_id" => new_user.id},
          ctx
        )

      assert res2.mentor_user_id == mentor.id

      # No active mentors (empty group)
      empty_group = create_user_group()

      {:error, err, _} =
        MentorshipPair.execute(
          %{"mentor_group_id" => empty_group.id},
          %{new_user_id: new_user.id},
          ctx
        )

      assert err =~ "No active mentors found"
    end

    test "SendCaptcha generates challenge question and validates config" do
      user = create_user()
      ctx = make_ctx()

      assert %{type: "verification/send_captcha"} = SendCaptcha.schema()
      assert :ok = SendCaptcha.validate_config(%{"captcha_type" => "math"})
      assert :ok = SendCaptcha.validate_config(%{"captcha_type" => "text"})
      assert {:error, _} = SendCaptcha.validate_config(%{"captcha_type" => "audio"})

      # Math captcha (contains question string)
      {:ok, res_math, u_ctx} =
        SendCaptcha.execute(%{"captcha_type" => "math"}, %{user_id: user.id}, ctx)

      assert is_binary(res_math.challenge_id)
      assert res_math.question =~ "?"
      assert u_ctx.db_operations > ctx.db_operations

      # Text captcha (hits question fallback "Please verify")
      {:ok, res_text, _} =
        SendCaptcha.execute(
          %{"captcha_type" => "text"},
          %{"user_id" => user.id},
          ctx
        )

      assert res_text.question == "Please verify"

      # Custom captcha type (hits other -> other branch)
      {:ok, res_other, _} =
        SendCaptcha.execute(
          %{"captcha_type" => "question"},
          %{"user_id" => user.id},
          ctx
        )

      assert is_binary(res_other.challenge_id)

      # Error branch (nil user_id)
      {:error, msg, _} =
        SendCaptcha.execute(%{"captcha_type" => "math"}, %{user_id: nil}, ctx)

      assert msg =~ "Failed to create captcha"
    end

    test "SendVerificationDm creates notification for user" do
      user = create_user()
      ctx = make_ctx()

      assert %{type: "verification/send_verification_dm"} = SendVerificationDm.schema()
      assert :ok = SendVerificationDm.validate_config(%{})

      # Success with atom keys
      {:ok, res, u_ctx} =
        SendVerificationDm.execute(
          %{"message_template" => "Welcome! Please verify."},
          %{user_id: user.id},
          ctx
        )

      assert res.success == true
      assert u_ctx.db_operations > ctx.db_operations

      # Success with string keys
      {:ok, res2, _} =
        SendVerificationDm.execute(
          %{},
          %{"user_id" => user.id},
          ctx
        )

      assert res2.success == true

      # Error branch (nil user_id)
      {:error, msg, _} =
        SendVerificationDm.execute(%{}, %{user_id: nil}, ctx)

      assert msg =~ "Failed to send verification DM"
    end

    test "VerifyCaptcha checks challenge answer and branches passed / failed" do
      user = create_user()
      {:ok, challenge} = ForgeNexus.Verification.create_challenge(user.id, "math_captcha")
      ctx = make_ctx()

      assert %{type: "verification/verify_captcha"} = VerifyCaptcha.schema()
      assert :ok = VerifyCaptcha.validate_config(%{})

      # Passed with correct answer
      {:branch, "passed", %{attempts: _}, u_ctx} =
        VerifyCaptcha.execute(
          %{},
          %{challenge_id: challenge.id, response: challenge.expected_answer},
          ctx
        )

      assert u_ctx.db_operations > ctx.db_operations

      # Failed with incorrect answer
      {:ok, challenge2} = ForgeNexus.Verification.create_challenge(user.id, "math_captcha")

      {:branch, "failed", %{attempts: 1}, _} =
        VerifyCaptcha.execute(
          %{},
          %{"challenge_id" => challenge2.id, "response" => "wrong_answer"},
          ctx
        )
    end
  end

  # =========================================================================
  # 6. Database Limit Check for all 43 Nodes
  # =========================================================================

  describe "DB limit enforcement" do
    test "All 43 nodes raise SandboxError when DB limit is reached" do
      ctx = make_ctx(%{db_operations: 100, max_db_ops: 50})

      inputs = %{
        user_id: "u",
        amount: 10,
        from_user_id: "f",
        to_user_id: "t",
        transaction_type: "award",
        description: "desc",
        item_id: "item",
        price: 10,
        points: 5,
        reason: "r",
        target_type: "post",
        target_ids: ["p1"],
        ip_address: "127.0.0.1",
        target_id: "t1",
        forum_id: "forum1",
        seconds: 10,
        duration_seconds: 60,
        title: "T",
        severity: "info",
        group_id: "g1",
        primary_user_id: "p1",
        secondary_user_id: "p2",
        request_id: "req1",
        approval_id: "app1",
        new_approver_id: "appr1",
        new_user_id: "u1",
        challenge_id: "c1",
        response: "ans"
      }

      nodes = [
        # Economy (12)
        AddInterest,
        AwardPoints,
        CheckBalance,
        CreateLotteryPool,
        CreateTransaction,
        CurrencyExchange,
        DeductPoints,
        GetBalance,
        GetLeaderboard,
        SetPrice,
        TaxTransaction,
        TransferPoints,
        # Moderation (10)
        AddInfraction,
        BulkDelete,
        CheckInfractionPoints,
        IpBan,
        QuarantineUser,
        SendModAlert,
        SetPostApproval,
        SlowMode,
        TimeoutUser,
        UnbanUser,
        # User Management (10)
        CheckOnlineStatus,
        CheckUserGroup,
        DemoteUser,
        GetUserProfile,
        MergeAccounts,
        PromoteUser,
        SetUserFlair,
        SetUserGroup,
        SetUserTitle,
        SetUsernameStyle,
        # Approval (3)
        AutoApproveOnTimeout,
        DelegateApproval,
        MultiLevelApproval,
        # Verification (8)
        AssignOnboardingChecklist,
        CheckAccountCriteria,
        CheckOnboardingComplete,
        CreateIntroductionPrompt,
        MentorshipPair,
        SendCaptcha,
        SendVerificationDm,
        VerifyCaptcha
      ]

      for node <- nodes do
        # Note: SendModAlert does not perform DB operations, but all others do
        if node != SendModAlert do
          assert_raise ForgeNexus.Plugins.Engine.SandboxError,
                       ~r/Database operation limit reached/,
                       fn ->
                         node.execute(%{}, inputs, ctx)
                       end
        end
      end
    end
  end
end
