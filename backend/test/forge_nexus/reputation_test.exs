defmodule ForgeNexus.ReputationTest do
  use ForgeNexus.DataCase, async: true

  alias ForgeNexus.Reputation
  alias ForgeNexus.Accounts.User

  defp insert_user!(opts \\ []) do
    n = System.unique_integer([:positive])
    rep = Keyword.get(opts, :reputation, 0)

    %User{
      username: "rep_user_#{n}",
      slug: "rep-user-#{n}",
      email: "rep_#{n}@example.com",
      password_hash: "$2b$12$dummyhash",
      reputation: rep
    }
    |> Repo.insert!()
  end

  describe "Reputation.award/3" do
    test "adds positive reputation to a user and logs an event" do
      user = insert_user!(reputation: 10)

      assert {:ok, result} = Reputation.award(user.id, 5, event_type: "helpful_answer")
      assert result.new_total == 15
      assert result.event.points == 5
      assert result.event.event_type == "helpful_answer"

      reloaded = Repo.get!(User, user.id)
      assert reloaded.reputation == 15
    end

    test "deducts negative reputation from a user" do
      user = insert_user!(reputation: 20)

      assert {:ok, result} = Reputation.award(user.id, -8, event_type: "moderation_strike")
      assert result.new_total == 12
      assert result.event.points == -8

      reloaded = Repo.get!(User, user.id)
      assert reloaded.reputation == 12
    end

    test "returns error if target user does not exist" do
      fake_id = Ecto.UUID.generate()
      assert {:error, :user_not_found} = Reputation.award(fake_id, 10)
    end
  end

  describe "Reputation.give_reputation/1" do
    test "transfers positive vote reputation to recipient" do
      giver = insert_user!()
      recipient = insert_user!(reputation: 5)

      params = %{
        from_user_id: giver.id,
        to_user_id: recipient.id,
        amount: 3,
        type: "positive"
      }

      assert {:ok, new_total} = Reputation.give_reputation(params)
      assert new_total == 8

      reloaded = Repo.get!(User, recipient.id)
      assert reloaded.reputation == 8
    end

    test "transfers negative vote reputation to recipient" do
      giver = insert_user!()
      recipient = insert_user!(reputation: 10)

      params = %{
        from_user_id: giver.id,
        to_user_id: recipient.id,
        amount: 4,
        type: "negative"
      }

      assert {:ok, new_total} = Reputation.give_reputation(params)
      assert new_total == 6

      reloaded = Repo.get!(User, recipient.id)
      assert reloaded.reputation == 6
    end
  end

  describe "Reputation.get_reputation/1 & current_score/1" do
    test "summarizes total score and positive/negative event counts" do
      user = insert_user!(reputation: 0)

      Reputation.award(user.id, 5)
      Reputation.award(user.id, 10)
      Reputation.award(user.id, -2)

      assert {:ok, stats} = Reputation.get_reputation(user.id)
      assert stats.total == 13
      assert stats.positive_count == 2
      assert stats.negative_count == 1

      assert Reputation.current_score(user.id) == 13
    end

    test "handles nonexistent user and nil parameter" do
      assert {:error, :missing_user_id} = Reputation.get_reputation(nil)
      assert {:error, :user_not_found} = Reputation.get_reputation(Ecto.UUID.generate())
      assert Reputation.current_score(nil) == 0
    end
  end

  describe "Reputation.get_trade_reputation/1" do
    test "summarizes trade-specific reputation from trade source events" do
      user = insert_user!(reputation: 0)

      Reputation.award(user.id, 1, event_type: "trade_complete", source_type: "trade")
      Reputation.award(user.id, 1, event_type: "trade_complete", source_type: "trade")
      Reputation.award(user.id, 5, event_type: "forum_post", source_type: "post")

      assert {:ok, trade_stats} = Reputation.get_trade_reputation(user.id)
      assert trade_stats.score == 2
      assert trade_stats.successful_trades == 2
      assert trade_stats.total_trades == 2
    end
  end
end
