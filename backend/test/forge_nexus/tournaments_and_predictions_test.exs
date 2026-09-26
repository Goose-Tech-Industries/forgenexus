defmodule ForgeNexus.TournamentsAndPredictionsTest do
  use ForgeNexus.DataCase, async: false

  alias ForgeNexus.{Accounts, Predictions, Repo, Tournaments}
  alias ForgeNexus.Accounts.User
  alias ForgeNexus.Tournaments.BracketGenerator
  alias ForgeNexus.Predictions.{PredictionOption, Suggestion}

  defp create_user(attrs \\ %{}) do
    unique_suffix = System.unique_integer([:positive])

    defaults = %{
      username: "tourney_user_#{unique_suffix}",
      email: "tourney_user_#{unique_suffix}@example.com",
      password: "SecurePass!987654#Alpha",
      password_confirmation: "SecurePass!987654#Alpha"
    }

    {:ok, user} =
      defaults
      |> Map.merge(Enum.into(attrs, %{}))
      |> Accounts.register_user()

    user
  end

  describe "Tournaments.BracketGenerator" do
    test "generates single elimination brackets with padding and byes" do
      # 4 players (exact power of 2)
      assert {:ok, bracket_4} =
               BracketGenerator.generate(["p1", "p2", "p3", "p4"], "single_elimination")

      assert bracket_4.format == "single_elimination"
      assert bracket_4.rounds == 2
      assert bracket_4.participant_count == 4
      assert length(bracket_4.matches) == 3

      # 3 players (requires bye padding to 4)
      assert {:ok, bracket_3} =
               BracketGenerator.generate(["p1", "p2", "p3"], "single_elimination")

      assert bracket_3.participant_count == 3
      bye_match = Enum.find(bracket_3.matches, fn m -> m.status == "bye" end)
      assert bye_match != nil
    end

    test "generates double elimination brackets" do
      assert {:ok, double_elim} =
               BracketGenerator.generate(["p1", "p2", "p3", "p4"], "double_elimination")

      assert double_elim.format == "double_elimination"
      assert is_list(double_elim.winners_bracket)
      assert is_list(double_elim.losers_bracket)
      assert double_elim.grand_final.id == "grand_final"
    end

    test "generates round robin brackets for even and odd player counts" do
      # Even count
      assert {:ok, rr_even} = BracketGenerator.generate(["p1", "p2", "p3", "p4"], "round_robin")
      assert rr_even.format == "round_robin"
      assert rr_even.rounds == 3
      assert length(rr_even.matches) == 6

      # Odd count (pairs with bye)
      assert {:ok, rr_odd} = BracketGenerator.generate(["p1", "p2", "p3"], "round_robin")
      assert rr_odd.format == "round_robin"
      assert length(rr_odd.matches) == 3
    end

    test "generates swiss rounds with and without existing standings" do
      # Round 1 without standings
      assert {:ok, sw_1} = BracketGenerator.generate(["p1", "p2", "p3", "p4"], "swiss")
      assert sw_1.format == "swiss"
      assert sw_1.round == 1
      assert length(sw_1.matches) == 2

      # Default format (single_elimination)
      assert {:ok, default_bracket} = BracketGenerator.generate(["p1", "p2"])
      assert default_bracket.format == "single_elimination"

      # Round 1 with standings
      assert {:ok, sw_2} =
               BracketGenerator.generate(["p1", "p2", "p3", "p4"], "swiss",
                 standings: %{"p1" => 3, "p2" => 0, "p3" => 1, "p4" => 1}
               )

      assert sw_2.format == "swiss"

      # Unknown format error
      assert {:error, :unknown_format} = BracketGenerator.generate(["p1", "p2"], "battle_royale")
    end
  end

  describe "Tournaments Context" do
    test "create, register, start, matchup, submit results, advance, standings, and complete" do
      user1 = create_user()
      user2 = create_user()
      user3 = create_user()
      user4 = create_user()

      # Create tournament
      {:ok, tournament} =
        Tournaments.create_tournament(%{
          name: "Championship 2026",
          format: "single_elimination",
          status: "registration",
          max_participants: 4,
          created_by_id: user1.id
        })

      assert tournament.status == "registration"

      # Register participants
      assert {:ok, _p1} = Tournaments.register_participant(tournament.id, user1.id)
      assert {:ok, _p2} = Tournaments.register_participant(tournament.id, user2.id)
      assert {:ok, _p3} = Tournaments.register_participant(tournament.id, user3.id)
      assert {:ok, _p4} = Tournaments.register_participant(tournament.id, user4.id)

      # Attempt registration when full
      user5 = create_user()

      assert {:error, :tournament_full} =
               Tournaments.register_participant(tournament.id, user5.id)

      # Start tournament
      assert {:ok, matches} = Tournaments.start_tournament(tournament.id)
      assert length(matches) == 2

      # Attempt registration when not in registration status
      assert {:error, :registration_closed} =
               Tournaments.register_participant(tournament.id, user5.id)

      # Get current matchup
      matchup1 = Tournaments.get_current_matchup(tournament.id, user1.id)
      assert matchup1 != nil
      assert matchup1.status == "active"

      # Cannot advance while matches are pending
      assert {:error, :matches_still_active} = Tournaments.advance_bracket(tournament.id)

      # Submit results for both round 1 matches
      [m1, m2] = matches
      assert {:ok, :ok} = Tournaments.submit_result(m1.id, m1.player1_id, %{"p1" => 2, "p2" => 0})
      assert {:ok, :ok} = Tournaments.submit_result(m2.id, m2.player1_id, %{"p1" => 2, "p2" => 1})

      # Advance bracket to round 2
      assert {:ok, round2_matches} = Tournaments.advance_bracket(tournament.id)
      assert length(round2_matches) == 1
      final_match = hd(round2_matches)
      assert final_match.round == 2

      # Submit result for final match
      assert {:ok, :ok} =
               Tournaments.submit_result(final_match.id, final_match.player1_id, %{
                 "p1" => 3,
                 "p2" => 2
               })

      # Advance bracket -> tournament complete
      assert {:ok, :tournament_complete} = Tournaments.advance_bracket(tournament.id)

      # Get standings
      standings = Tournaments.get_standings(tournament.id)
      assert length(standings) == 4
      assert hd(standings).wins >= 1
      assert hd(standings).points >= 3

      # Complete tournament
      assert {:ok, completed} = Tournaments.complete_tournament(tournament.id)
      assert completed.status == "completed"
    end

    test "tournament with odd participants assigns bye" do
      u1 = create_user()
      u2 = create_user()
      u3 = create_user()

      {:ok, tournament} =
        Tournaments.create_tournament(%{
          name: "Odd Tourney",
          format: "single_elimination",
          status: "registration",
          created_by_id: u1.id
        })

      assert {:ok, _} = Tournaments.register_participant(tournament.id, u1.id)
      assert {:ok, _} = Tournaments.register_participant(tournament.id, u2.id)
      assert {:ok, _} = Tournaments.register_participant(tournament.id, u3.id)

      assert {:ok, matches} = Tournaments.start_tournament(tournament.id)
      assert Enum.any?(matches, fn m -> m.status == "bye" end)
    end
  end

  describe "Predictions Context" do
    test "full prediction market lifecycle: create, bet, resolve with payouts, cancel with refunds" do
      creator = create_user()
      bettor1 = create_user()
      bettor2 = create_user()

      # Give users points to bet
      Ecto.Changeset.change(bettor1, %{points: 500}) |> Repo.update!()
      Ecto.Changeset.change(bettor2, %{points: 500}) |> Repo.update!()

      # Create prediction
      {:ok, prediction} =
        Predictions.create_prediction(%{
          title: "Will Team Alpha win the championship?",
          description: "Resolves after finals match",
          status: "open",
          created_by_id: creator.id
        })

      # Add options
      opt_yes =
        %PredictionOption{}
        |> PredictionOption.changeset(%{prediction_id: prediction.id, label: "Yes"})
        |> Repo.insert!()

      opt_no =
        %PredictionOption{}
        |> PredictionOption.changeset(%{prediction_id: prediction.id, label: "No"})
        |> Repo.insert!()

      # List predictions
      open_preds = Predictions.list_predictions("open")
      assert Enum.any?(open_preds, fn p -> p.id == prediction.id end)

      all_preds = Predictions.list_predictions()
      assert Enum.any?(all_preds, fn p -> p.id == prediction.id end)

      # Place bets
      assert {:ok, bet1} = Predictions.place_bet(bettor1.id, opt_yes.id, 100)
      assert bet1.amount == 100

      assert {:ok, bet2} = Predictions.place_bet(bettor2.id, opt_no.id, 50)
      assert bet2.amount == 50

      # Bettor with insufficient points
      poor_user = create_user()
      assert {:error, :insufficient_points} = Predictions.place_bet(poor_user.id, opt_yes.id, 100)

      # Resolve prediction: "Yes" wins
      # Pool: 150 total. Bettor 1 put 100 on winning pool of 100 -> gets all 150 points!
      assert {:ok, resolved} = Predictions.resolve_prediction(prediction.id, "Yes")
      assert resolved.status == "resolved"
      assert resolved.winning_option == "Yes"

      # Verify bettor 1 received winnings (500 - 100 + 150 = 550)
      assert Repo.get!(User, bettor1.id).points == 550

      # Attempt bet on resolved prediction
      assert {:error, :prediction_not_open} = Predictions.place_bet(bettor1.id, opt_yes.id, 50)

      # Attempt resolving with invalid option
      assert {:error, :invalid_option} = Predictions.resolve_prediction(prediction.id, "Maybe")

      # Test Cancellation and Refunds
      {:ok, cancel_pred} =
        Predictions.create_prediction(%{
          title: "Cancelled match prediction",
          status: "open",
          created_by_id: creator.id
        })

      cancel_opt =
        %PredictionOption{}
        |> PredictionOption.changeset(%{prediction_id: cancel_pred.id, label: "Option A"})
        |> Repo.insert!()

      {:ok, _cancel_bet} = Predictions.place_bet(bettor2.id, cancel_opt.id, 100)
      # Bettor 2 points were 500 - 50 - 100 = 350
      assert Repo.get!(User, bettor2.id).points == 350

      assert {:ok, cancelled} = Predictions.cancel_prediction(cancel_pred.id)
      assert cancelled.status == "cancelled"

      # Bettor 2 was refunded 100 points -> 450
      assert Repo.get!(User, bettor2.id).points == 450
    end

    test "suggestions voting and status updates" do
      user = create_user()
      voter1 = create_user()
      voter2 = create_user()

      {:ok, suggestion} =
        Predictions.create_suggestion(%{
          title: "Add dark mode to brackets",
          description: "High contrast UI for brackets",
          user_id: user.id
        })

      # First upvote
      assert {:ok, :ok} = Predictions.vote_suggestion(suggestion.id, voter1.id, :up)
      updated1 = Repo.get!(Suggestion, suggestion.id)
      assert updated1.upvotes == 1

      # Duplicate vote error
      assert {:error, :already_voted} = Predictions.vote_suggestion(suggestion.id, voter1.id, :up)

      # Switch vote to downvote
      assert {:ok, :ok} = Predictions.vote_suggestion(suggestion.id, voter1.id, :down)
      updated2 = Repo.get!(Suggestion, suggestion.id)
      assert updated2.upvotes == 0
      assert updated2.downvotes == 1

      # Second voter upvotes
      assert {:ok, :ok} = Predictions.vote_suggestion(suggestion.id, voter2.id, :up)
      updated3 = Repo.get!(Suggestion, suggestion.id)
      assert updated3.upvotes == 1
      assert updated3.downvotes == 1

      # Update status
      assert {:ok, approved} = Predictions.update_suggestion_status(suggestion.id, "approved")
      assert approved.status == "approved"
    end
  end
end
