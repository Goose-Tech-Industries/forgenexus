defmodule ForgeNexus.Plugins.NodesCommunityTest do
  use ForgeNexus.DataCase, async: false

  alias ForgeNexus.Plugins.Engine.Context
  alias ForgeNexus.Accounts
  alias ForgeNexus.Forums
  alias ForgeNexus.Tournaments
  alias ForgeNexus.Tickets
  alias ForgeNexus.UserStats

  # Ticket nodes (8)
  alias ForgeNexus.Plugins.Nodes.Ticket.{
    AddInternalNote,
    AssignTicket,
    ClaimTicket,
    CloseWithRating,
    CreateTicket,
    EscalateTicket,
    TicketSlaCheck,
    UpdateTicketStatus
  }

  # Tournament nodes (8)
  alias ForgeNexus.Plugins.Nodes.Tournament.{
    AdvanceBracket,
    AwardPlacement,
    CreateSeason,
    CreateTournament,
    GetMatchup,
    GetStandings,
    RegisterParticipant,
    SubmitResult
  }

  # Poll nodes (8)
  alias ForgeNexus.Plugins.Nodes.Poll.{
    AddVote,
    ClosePoll,
    CreatePoll,
    CreatePrediction,
    CreateSuggestion,
    GetPollResults,
    ResolvePrediction,
    UpdateSuggestionStatus
  }

  # Shoutbox nodes (8)
  alias ForgeNexus.Plugins.Nodes.Shoutbox.{
    ClearShoutbox,
    DeleteShout,
    GetShoutboxStats,
    MuteUserShoutbox,
    PinShout,
    SendAnnouncement,
    SendShout,
    ShoutboxCooldown
  }

  # Reputation nodes (6)
  alias ForgeNexus.Plugins.Nodes.Reputation.{
    CheckReputation,
    GetReputation,
    GetTradeRep,
    GiveReputation,
    ReputationDecay,
    ScaleRepPower
  }

  # Stats nodes (6)
  alias ForgeNexus.Plugins.Nodes.Stats.{
    CheckStat,
    GetAllStats,
    GetLevel,
    GetStat,
    ModifyStat,
    SetStat
  }

  defp make_ctx(overrides \\ %{}) do
    base = %Context{
      execution_id: Ecto.UUID.generate(),
      flow_id: Ecto.UUID.generate(),
      community_id: Ecto.UUID.generate(),
      started_at: DateTime.utc_now()
    }

    Map.merge(base, overrides)
  end

  defp create_user do
    unique = System.unique_integer([:positive])

    {:ok, user} =
      Accounts.register_user(%{
        username: "comm_u_#{unique}",
        email: "comm_u_#{unique}@example.com",
        password: "ValidPassword123!@#"
      })

    user
  end

  defp create_forum_and_thread(user) do
    unique = System.unique_integer([:positive])
    {:ok, cat} = Forums.create_category(%{name: "Comm Cat #{unique}", position: 0})

    {:ok, forum} =
      Forums.create_forum(%{name: "Comm Forum #{unique}", category_id: cat.id, position: 0})

    {:ok, thread} =
      Forums.create_thread(%{
        "forum_id" => forum.id,
        "user_id" => user.id,
        "title" => "Thread #{unique}",
        "body" => "Thread body #{unique}"
      })

    {forum, thread}
  end

  # ============================================================================
  # 1. TICKET NODES (8)
  # ============================================================================

  describe "Ticket nodes" do
    test "CreateTicket executes successfully and validates config" do
      user = create_user()
      ctx = make_ctx()

      assert %{type: "ticket/create_ticket"} = CreateTicket.schema()
      assert :ok = CreateTicket.validate_config(%{"priority" => "urgent"})
      assert {:error, _} = CreateTicket.validate_config(%{"priority" => "invalid_prio"})

      # Success with atom inputs
      {:ok, res, updated_ctx} =
        CreateTicket.execute(
          %{"priority" => "high", "category" => "Billing"},
          %{user_id: user.id, title: "Help me", description: "Need billing assistance"},
          ctx
        )

      assert res.success == true
      assert is_binary(res.ticket_id)
      assert updated_ctx.db_operations > ctx.db_operations

      # Success with string inputs
      {:ok, res2, _} =
        CreateTicket.execute(
          %{},
          %{"user_id" => user.id, "title" => "Question", "description" => "How to play?"},
          ctx
        )

      assert res2.success == true

      # Failure branch (missing title/description)
      {:error, msg, _} =
        CreateTicket.execute(
          %{},
          %{user_id: user.id, title: nil, description: nil},
          ctx
        )

      assert msg =~ "Failed to create ticket"
    end

    test "AddInternalNote executes successfully and handles errors" do
      user = create_user()
      staff = create_user()
      ctx = make_ctx()

      {:ok, ticket} =
        Tickets.create_ticket(%{
          user_id: user.id,
          title: "Issue",
          description: "Details",
          status: "open"
        })

      assert %{type: "ticket/add_internal_note"} = AddInternalNote.schema()
      assert :ok = AddInternalNote.validate_config(%{})

      # Success with atom keys
      {:ok, res, updated_ctx} =
        AddInternalNote.execute(
          %{},
          %{ticket_id: ticket.id, user_id: staff.id, body: "Staff internal observation"},
          ctx
        )

      assert res.success == true
      assert is_binary(res.message_id)
      assert updated_ctx.db_operations > ctx.db_operations

      # Success with string keys
      {:ok, res2, _} =
        AddInternalNote.execute(
          %{},
          %{"ticket_id" => ticket.id, "user_id" => staff.id, "body" => "Another note"},
          ctx
        )

      assert res2.success == true

      # Error branch (invalid ticket_id)
      {:error, msg, _} =
        AddInternalNote.execute(
          %{},
          %{ticket_id: Ecto.UUID.generate(), user_id: staff.id, body: nil},
          ctx
        )

      assert msg =~ "Failed to add note"
    end

    test "AssignTicket executes successfully and handles non-existent ticket" do
      user = create_user()
      staff = create_user()
      ctx = make_ctx()

      {:ok, ticket} =
        Tickets.create_ticket(%{
          user_id: user.id,
          title: "Assign test",
          description: "Details",
          status: "open"
        })

      assert %{type: "ticket/assign_ticket"} = AssignTicket.schema()
      assert :ok = AssignTicket.validate_config(%{})

      # Success with atom keys
      {:ok, res, updated_ctx} =
        AssignTicket.execute(%{}, %{ticket_id: ticket.id, staff_user_id: staff.id}, ctx)

      assert res.success == true
      assert updated_ctx.db_operations > ctx.db_operations

      # Success with string keys
      {:ok, res2, _} =
        AssignTicket.execute(
          %{},
          %{"ticket_id" => ticket.id, "staff_user_id" => staff.id},
          ctx
        )

      assert res2.success == true

      # Error branch (non-existent ticket)
      {:error, msg, _} =
        AssignTicket.execute(
          %{},
          %{ticket_id: Ecto.UUID.generate(), staff_user_id: staff.id},
          ctx
        )

      assert msg =~ "Failed to assign ticket"
    end

    test "ClaimTicket executes successfully and handles errors" do
      user = create_user()
      staff = create_user()
      ctx = make_ctx()

      {:ok, ticket} =
        Tickets.create_ticket(%{
          user_id: user.id,
          title: "Claim test",
          description: "Details",
          status: "open"
        })

      assert %{type: "ticket/claim_ticket"} = ClaimTicket.schema()
      assert :ok = ClaimTicket.validate_config(%{})

      # Success with atom keys
      {:ok, res, updated_ctx} =
        ClaimTicket.execute(%{}, %{ticket_id: ticket.id, staff_user_id: staff.id}, ctx)

      assert res.success == true
      assert updated_ctx.db_operations > ctx.db_operations

      # Success with string keys
      {:ok, res2, _} =
        ClaimTicket.execute(
          %{},
          %{"ticket_id" => ticket.id, "staff_user_id" => staff.id},
          ctx
        )

      assert res2.success == true

      # Error branch
      {:error, msg, _} =
        ClaimTicket.execute(%{}, %{ticket_id: Ecto.UUID.generate(), staff_user_id: staff.id}, ctx)

      assert msg =~ "Failed to claim ticket"
    end

    test "CloseWithRating executes with integer, float, string ratings and bounds checks" do
      user = create_user()
      ctx = make_ctx()

      {:ok, ticket} =
        Tickets.create_ticket(%{
          user_id: user.id,
          title: "Close rating test",
          description: "Details",
          status: "open"
        })

      assert %{type: "ticket/close_with_rating"} = CloseWithRating.schema()
      assert :ok = CloseWithRating.validate_config(%{})

      # Rating out of bounds (< 1)
      {:error, err, _} = CloseWithRating.execute(%{}, %{ticket_id: ticket.id, rating: 0}, ctx)
      assert err =~ "between 1 and 5"

      # Rating out of bounds (> 5)
      {:error, err2, _} = CloseWithRating.execute(%{}, %{ticket_id: ticket.id, rating: 6}, ctx)
      assert err2 =~ "between 1 and 5"

      # String rating parsed to int
      {:ok, res, updated_ctx} =
        CloseWithRating.execute(%{}, %{ticket_id: ticket.id, rating: "5"}, ctx)

      assert res.success == true
      assert updated_ctx.db_operations > ctx.db_operations

      # Float rating
      {:ok, ticket2} =
        Tickets.create_ticket(%{
          user_id: user.id,
          title: "Close rating test 2",
          description: "Details",
          status: "open"
        })

      {:ok, res2, _} =
        CloseWithRating.execute(%{}, %{"ticket_id" => ticket2.id, "rating" => 4.0}, ctx)

      assert res2.success == true

      # Fallback non-number rating -> defaults to 0 -> fails rating check
      {:error, err3, _} =
        CloseWithRating.execute(%{}, %{ticket_id: ticket2.id, rating: :bad}, ctx)

      assert err3 =~ "between 1 and 5"

      # String rating parse failure
      {:error, err_str_parse, _} =
        CloseWithRating.execute(%{}, %{ticket_id: ticket2.id, rating: "abc"}, ctx)

      assert err_str_parse =~ "between 1 and 5"

      # Error branch on nonexistent ticket
      {:error, msg, _} =
        CloseWithRating.execute(%{}, %{ticket_id: Ecto.UUID.generate(), rating: 5}, ctx)

      assert msg =~ "Failed to close"
    end

    test "EscalateTicket executes successfully and handles errors" do
      user = create_user()
      ctx = make_ctx()

      {:ok, ticket} =
        Tickets.create_ticket(%{
          user_id: user.id,
          title: "Escalate test",
          description: "Details",
          status: "open"
        })

      assert %{type: "ticket/escalate_ticket"} = EscalateTicket.schema()
      assert :ok = EscalateTicket.validate_config(%{})

      # Success with atom keys
      {:ok, res, updated_ctx} =
        EscalateTicket.execute(
          %{"reason" => "Needs tier 2 support"},
          %{ticket_id: ticket.id},
          ctx
        )

      assert res.success == true
      assert updated_ctx.db_operations > ctx.db_operations

      # Success with string keys
      {:ok, res2, _} =
        EscalateTicket.execute(%{}, %{"ticket_id" => ticket.id}, ctx)

      assert res2.success == true

      # Error branch
      {:error, msg, _} =
        EscalateTicket.execute(%{}, %{ticket_id: Ecto.UUID.generate()}, ctx)

      assert msg =~ "Failed to escalate"
    end

    test "TicketSlaCheck branches correctly and validates config" do
      user = create_user()
      ctx = make_ctx()

      assert %{type: "ticket/ticket_sla_check"} = TicketSlaCheck.schema()
      assert :ok = TicketSlaCheck.validate_config(%{"max_response_hours" => 12})
      assert :ok = TicketSlaCheck.validate_config(%{"max_response_hours" => "24.5"})
      assert :ok = TicketSlaCheck.validate_config(%{})
      assert {:error, _} = TicketSlaCheck.validate_config(%{"max_response_hours" => -1})
      assert {:error, _} = TicketSlaCheck.validate_config(%{"max_response_hours" => "invalid"})
      assert {:error, _} = TicketSlaCheck.validate_config(%{"max_response_hours" => :bad})

      {:ok, ticket} =
        Tickets.create_ticket(%{
          user_id: user.id,
          title: "SLA test",
          description: "Details",
          status: "open"
        })

      # Within SLA branch (threshold 24h, ticket just created)
      {:branch, "within_sla", outputs, updated_ctx} =
        TicketSlaCheck.execute(%{"max_response_hours" => 24}, %{ticket_id: ticket.id}, ctx)

      assert outputs.hours_elapsed >= 0.0
      assert outputs.threshold == 24
      assert updated_ctx.db_operations > ctx.db_operations

      # String threshold
      {:branch, "within_sla", _, _} =
        TicketSlaCheck.execute(%{"max_response_hours" => "24"}, %{"ticket_id" => ticket.id}, ctx)

      # Breached branch (update inserted_at to 48 hours ago)
      past_time = NaiveDateTime.utc_now() |> NaiveDateTime.add(-48 * 3600, :second)

      import Ecto.Query

      from(t in ForgeNexus.Tickets.Ticket, where: t.id == ^ticket.id)
      |> ForgeNexus.Repo.update_all(set: [inserted_at: past_time])

      {:branch, "breached", _, _} =
        TicketSlaCheck.execute(%{"max_response_hours" => 24}, %{ticket_id: ticket.id}, ctx)

      # Nonexistent ticket -> defaults to 0.0 hours elapsed -> within SLA
      {:branch, "within_sla", outputs_missing, _} =
        TicketSlaCheck.execute(
          %{"max_response_hours" => 10},
          %{ticket_id: Ecto.UUID.generate()},
          ctx
        )

      assert outputs_missing.hours_elapsed == 0.0

      # Fallback non-number threshold
      {:branch, _, _, _} =
        TicketSlaCheck.execute(
          %{"max_response_hours" => :invalid_threshold},
          %{ticket_id: ticket.id},
          ctx
        )

      # String parse failure threshold
      {:branch, _, _, _} =
        TicketSlaCheck.execute(
          %{"max_response_hours" => "not_a_num"},
          %{ticket_id: ticket.id},
          ctx
        )
    end

    test "UpdateTicketStatus executes successfully and validates config" do
      user = create_user()
      ctx = make_ctx()

      {:ok, ticket} =
        Tickets.create_ticket(%{
          user_id: user.id,
          title: "Status update test",
          description: "Details",
          status: "open"
        })

      assert %{type: "ticket/update_ticket_status"} = UpdateTicketStatus.schema()
      assert :ok = UpdateTicketStatus.validate_config(%{"status" => "in_progress"})
      assert {:error, _} = UpdateTicketStatus.validate_config(%{"status" => "unknown_status"})

      # Success with atom keys
      {:ok, res, updated_ctx} =
        UpdateTicketStatus.execute(
          %{"status" => "in_progress"},
          %{ticket_id: ticket.id},
          ctx
        )

      assert res.success == true
      assert res.previous_status == "open"
      assert updated_ctx.db_operations > ctx.db_operations

      # Success with string keys
      {:ok, res2, _} =
        UpdateTicketStatus.execute(
          %{"status" => "resolved"},
          %{"ticket_id" => ticket.id},
          ctx
        )

      assert res2.success == true
      assert res2.previous_status == "in_progress"

      # Error branch
      {:error, msg, _} =
        UpdateTicketStatus.execute(
          %{"status" => "closed"},
          %{ticket_id: Ecto.UUID.generate()},
          ctx
        )

      assert msg =~ "Failed to update status"
    end
  end

  # ============================================================================
  # 2. TOURNAMENT NODES (8)
  # ============================================================================

  describe "Tournament nodes" do
    test "CreateTournament executes successfully and validates config" do
      user = create_user()
      ctx = make_ctx()

      assert %{type: "tournament/create_tournament"} = CreateTournament.schema()

      assert :ok =
               CreateTournament.validate_config(%{
                 "format" => "single_elimination",
                 "max_participants" => 16
               })

      assert :ok = CreateTournament.validate_config(%{"format" => "single_elimination"})

      assert {:error, _} =
               CreateTournament.validate_config(%{
                 "format" => "single_elimination",
                 "max_participants" => "not_a_num"
               })

      assert {:error, _} = CreateTournament.validate_config(%{"format" => "battle_royale"})

      assert {:error, _} =
               CreateTournament.validate_config(%{"format" => "swiss", "max_participants" => -5})

      # Success with atom inputs
      {:ok, res, updated_ctx} =
        CreateTournament.execute(
          %{"format" => "round_robin", "max_participants" => 8},
          %{name: "Spring Championship", description: "Seasonal cup", user_id: user.id},
          ctx
        )

      assert res.success == true
      assert is_binary(res.tournament_id)
      assert updated_ctx.db_operations > ctx.db_operations

      # Success with string inputs
      {:ok, res2, _} =
        CreateTournament.execute(
          %{},
          %{"name" => "Summer Cup", "description" => "Fun tourney", "user_id" => user.id},
          ctx
        )

      assert res2.success == true

      # Failure branch (missing name)
      {:error, msg, _} =
        CreateTournament.execute(
          %{"format" => "single_elimination"},
          %{name: nil},
          ctx
        )

      assert msg =~ "Failed to create tournament"
    end

    test "CreateSeason executes successfully and validates config" do
      user = create_user()
      ctx = make_ctx()

      assert %{type: "tournament/create_season"} = CreateSeason.schema()

      assert :ok =
               CreateSeason.validate_config(%{
                 "duration_days" => 60,
                 "reward_tiers" => %{"1" => 1000}
               })

      assert :ok = CreateSeason.validate_config(%{"reward_tiers" => "{\"1\": 500}"})
      assert :ok = CreateSeason.validate_config(%{})
      assert {:error, _} = CreateSeason.validate_config(%{"duration_days" => -1})
      assert {:error, _} = CreateSeason.validate_config(%{"reward_tiers" => "invalid json {"})
      assert {:error, _} = CreateSeason.validate_config(%{"reward_tiers" => 12345})

      # Success with integer duration_days
      {:ok, res_int, _} =
        CreateSeason.execute(
          %{"duration_days" => 30},
          %{name: "Season Int", user_id: user.id},
          ctx
        )

      assert res_int.success == true

      # Success with float duration_days, string inputs
      {:ok, res, updated_ctx} =
        CreateSeason.execute(
          %{"duration_days" => 45.0, "format" => "round_robin"},
          %{"name" => "Season 1", "description" => "First ranked season", "user_id" => user.id},
          ctx
        )

      assert res.success == true
      assert is_binary(res.season_id)
      assert updated_ctx.db_operations > ctx.db_operations

      # Success with string duration_days and atom inputs
      {:ok, res2, _} =
        CreateSeason.execute(
          %{"duration_days" => "30"},
          %{name: "Season 2", description: "Second season", user_id: user.id},
          ctx
        )

      assert res2.success == true

      # Invalid string duration_days fallback
      {:ok, res3, _} =
        CreateSeason.execute(
          %{"duration_days" => "invalid_num"},
          %{name: "Season 3", user_id: user.id},
          ctx
        )

      assert res3.success == true

      # Fallback non-number duration_days
      {:ok, res4, _} =
        CreateSeason.execute(
          %{"duration_days" => :not_a_day},
          %{name: "Season 4", user_id: user.id},
          ctx
        )

      assert res4.success == true

      # Failure branch (missing name)
      {:error, msg, _} =
        CreateSeason.execute(
          %{},
          %{name: nil},
          ctx
        )

      assert msg =~ "Failed to create season"
    end

    test "RegisterParticipant executes successfully and handles capacity limits" do
      u1 = create_user()
      u2 = create_user()
      ctx = make_ctx()

      {:ok, tourney} =
        Tournaments.create_tournament(%{
          name: "Open Tourney",
          format: "single_elimination",
          max_participants: 1,
          status: "registration",
          created_by_id: u1.id
        })

      assert %{type: "tournament/register_participant"} = RegisterParticipant.schema()
      assert :ok = RegisterParticipant.validate_config(%{})

      # Success with atom keys
      {:ok, res, updated_ctx} =
        RegisterParticipant.execute(%{}, %{tournament_id: tourney.id, user_id: u1.id}, ctx)

      assert res.success == true
      assert is_binary(res.participant_id)
      assert updated_ctx.db_operations > ctx.db_operations

      # Full tournament failure with string keys
      {:error, msg, _} =
        RegisterParticipant.execute(
          %{},
          %{"tournament_id" => tourney.id, "user_id" => u2.id},
          ctx
        )

      assert msg =~ "tournament_full"
    end

    test "GetMatchup, SubmitResult, AdvanceBracket, GetStandings and AwardPlacement execute full flow" do
      u1 = create_user()
      u2 = create_user()
      ctx = make_ctx()

      {:ok, tourney} =
        Tournaments.create_tournament(%{
          name: "Championship",
          format: "single_elimination",
          max_participants: 2,
          status: "registration",
          created_by_id: u1.id
        })

      {:ok, _p1} = Tournaments.register_participant(tourney.id, u1.id)
      {:ok, _p2} = Tournaments.register_participant(tourney.id, u2.id)

      # Start tournament creates matches
      {:ok, [match | _]} = Tournaments.start_tournament(tourney.id)

      # 1. GetMatchup tests
      assert %{type: "tournament/get_matchup"} = GetMatchup.schema()
      assert :ok = GetMatchup.validate_config(%{})

      # Has match
      {:ok, matchup_res, u_ctx} =
        GetMatchup.execute(%{}, %{tournament_id: tourney.id, user_id: u1.id}, ctx)

      assert matchup_res.has_match == true
      assert matchup_res.match.match_id == match.id
      assert matchup_res.match.opponent == u2.id
      assert u_ctx.db_operations > ctx.db_operations

      # When checking as player 2, opponent should be player 1
      {:ok, matchup_res2, _} =
        GetMatchup.execute(%{}, %{"tournament_id" => tourney.id, "user_id" => u2.id}, ctx)

      assert matchup_res2.has_match == true
      assert matchup_res2.match.opponent == u1.id

      # No matchup for unrelated user
      unrelated_user = create_user()

      {:ok, no_match, _} =
        GetMatchup.execute(%{}, %{tournament_id: tourney.id, user_id: unrelated_user.id}, ctx)

      assert no_match.has_match == false
      assert is_nil(no_match.match)

      # 2. AdvanceBracket while matches are active
      assert %{type: "tournament/advance_bracket"} = AdvanceBracket.schema()
      assert :ok = AdvanceBracket.validate_config(%{})

      {:error, adv_err, _} =
        AdvanceBracket.execute(%{}, %{tournament_id: tourney.id}, ctx)

      assert adv_err =~ "matches_still_active"

      # 3. SubmitResult tests
      assert %{type: "tournament/submit_result"} = SubmitResult.schema()
      assert :ok = SubmitResult.validate_config(%{})

      # Valid result submission
      {:ok, sub_res, _} =
        SubmitResult.execute(
          %{"player1_score" => 3, "player2_score" => 1},
          %{match_id: match.id, winner_id: u1.id},
          ctx
        )

      assert sub_res.success == true

      # Result submission with string keys on invalid match
      {:error, sub_err, _} =
        SubmitResult.execute(
          %{},
          %{"match_id" => Ecto.UUID.generate(), "winner_id" => u1.id},
          ctx
        )

      assert sub_err =~ "Failed to submit result"

      # 4. AdvanceBracket completes tournament (single winner)
      {:ok, adv_done, _} =
        AdvanceBracket.execute(%{}, %{"tournament_id" => tourney.id}, ctx)

      assert adv_done.tournament_complete == true
      assert adv_done.matches_created == 0

      # AdvanceBracket creates next round matches when multiple winners remain
      u3 = create_user()
      u4 = create_user()

      {:ok, t4} =
        Tournaments.create_tournament(%{
          name: "4 Player Tourney",
          format: "single_elimination",
          max_participants: 4,
          status: "registration",
          created_by_id: u1.id
        })

      {:ok, _} = Tournaments.register_participant(t4.id, u1.id)
      {:ok, _} = Tournaments.register_participant(t4.id, u2.id)
      {:ok, _} = Tournaments.register_participant(t4.id, u3.id)
      {:ok, _} = Tournaments.register_participant(t4.id, u4.id)

      {:ok, [m1, m2]} = Tournaments.start_tournament(t4.id)

      {:ok, _} = Tournaments.submit_result(m1.id, m1.player1_id, %{})
      {:ok, _} = Tournaments.submit_result(m2.id, m2.player1_id, %{})

      {:ok, adv_next, _} = AdvanceBracket.execute(%{}, %{tournament_id: t4.id}, ctx)
      assert adv_next.tournament_complete == false
      assert adv_next.matches_created == 1

      # 5. GetStandings tests
      assert %{type: "tournament/get_standings"} = GetStandings.schema()
      assert :ok = GetStandings.validate_config(%{"limit" => 10})

      {:ok, standings_res, _} =
        GetStandings.execute(%{"limit" => 5}, %{"tournament_id" => tourney.id}, ctx)

      assert standings_res.count == 2
      assert is_list(standings_res.standings)

      # 6. AwardPlacement tests
      assert %{type: "tournament/award_placement"} = AwardPlacement.schema()
      assert :ok = AwardPlacement.validate_config(%{"prizes" => %{"1" => 1000, "2" => 500}})
      assert :ok = AwardPlacement.validate_config(%{"prizes" => "{\"1\": 500}"})
      assert :ok = AwardPlacement.validate_config(%{})
      assert {:error, _} = AwardPlacement.validate_config(%{"prizes" => "invalid { json"})
      assert {:error, _} = AwardPlacement.validate_config(%{"prizes" => 1234})

      # Award placement with map prizes
      {:ok, award_res, _} =
        AwardPlacement.execute(
          %{"prizes" => %{1 => 100, 2 => 50, 99 => 10}},
          %{tournament_id: tourney.id},
          ctx
        )

      assert award_res.success == true
      assert award_res.awards_given >= 2

      # Award placement with valid JSON prizes string
      {:ok, award_res2, _} =
        AwardPlacement.execute(
          %{"prizes" => "{\"1\": 200, \"2\": 100}"},
          %{"tournament_id" => tourney.id},
          ctx
        )

      assert award_res2.success == true

      # Award placement with invalid JSON string and invalid type prizes
      {:ok, award_res3, _} =
        AwardPlacement.execute(%{"prizes" => "not_json"}, %{tournament_id: tourney.id}, ctx)

      assert award_res3.awards_given == 0

      {:ok, award_res4, _} =
        AwardPlacement.execute(%{"prizes" => 999}, %{tournament_id: tourney.id}, ctx)

      assert award_res4.awards_given == 0

      # Award placement for nonexistent tournament (rescues cleanly)
      {:ok, award_res5, _} =
        AwardPlacement.execute(%{}, %{tournament_id: Ecto.UUID.generate()}, ctx)

      assert award_res5.awards_given == 0
    end
  end

  # ============================================================================
  # 3. POLL NODES (8)
  # ============================================================================

  describe "Poll nodes" do
    test "CreatePoll executes with thread_id or auto-creates thread and validates config" do
      user = create_user()
      {forum, thread} = create_forum_and_thread(user)
      ctx = make_ctx(%{user_id: user.id})

      assert %{type: "poll/create_poll"} = CreatePoll.schema()
      assert :ok = CreatePoll.validate_config(%{"options" => "Option A, Option B"})
      assert {:error, _} = CreatePoll.validate_config(%{"options" => ""})
      assert {:error, _} = CreatePoll.validate_config(%{"options" => nil})
      assert {:error, _} = CreatePoll.validate_config(%{"options" => "OnlyOne"})
      assert {:error, _} = CreatePoll.validate_config(%{"options" => 1234})

      # Success with existing thread_id
      {:ok, poll_res, u_ctx} =
        CreatePoll.execute(
          %{
            "options" => "Option 1, Option 2, Option 3",
            "duration_hours" => 48,
            "allow_multiple" => true
          },
          %{question: "Favorite language?", thread_id: thread.id},
          ctx
        )

      assert poll_res.success == true
      assert is_binary(poll_res.poll_id)
      assert poll_res.thread_id == thread.id
      assert u_ctx.db_operations > ctx.db_operations

      # Success with auto-created thread (forum_id + user_id)
      {:ok, poll_res2, _} =
        CreatePoll.execute(
          %{"options" => "Yes, No", "duration_hours" => "12.5"},
          %{"question" => "Do you agree?", "forum_id" => forum.id, "user_id" => user.id},
          ctx
        )

      assert poll_res2.success == true
      assert is_binary(poll_res2.poll_id)
      assert is_binary(poll_res2.thread_id)

      # Error: options < 2
      {:error, err1, _} =
        CreatePoll.execute(
          %{"options" => "Solo"},
          %{question: "Q", thread_id: thread.id},
          ctx
        )

      assert err1 =~ "at least 2 options"

      # Error: neither thread_id nor forum_id/user_id
      {:error, err2, _} =
        CreatePoll.execute(
          %{"options" => "A, B"},
          %{question: "Q", thread_id: nil, forum_id: nil, user_id: nil},
          make_ctx(%{user_id: nil})
        )

      assert err2 =~ "Either thread_id, or both forum_id and user_id are required"

      # Error: auto-creating thread failure
      {:error, err3, _} =
        CreatePoll.execute(
          %{"options" => "A, B"},
          %{question: "Q", forum_id: Ecto.UUID.generate(), user_id: user.id},
          ctx
        )

      assert err3 =~ "Failed to auto-create poll thread"

      # Error: spam detected in question
      {:error, spam_err, _} =
        CreatePoll.execute(
          %{"options" => "A, B"},
          %{question: "cheap viagra discounts", forum_id: forum.id, user_id: user.id},
          ctx
        )

      assert spam_err =~ "Poll thread rejected"

      # Error: create_poll failure (nil question)
      {:error, poll_fail_err, _} =
        CreatePoll.execute(
          %{"options" => "A, B"},
          %{question: nil, thread_id: thread.id},
          ctx
        )

      assert poll_fail_err =~ "Failed to create poll"

      # Fallback non-number / invalid string duration_hours
      {_, thread2} = create_forum_and_thread(user)
      {_, thread3} = create_forum_and_thread(user)

      {:ok, _, _} =
        CreatePoll.execute(
          %{"options" => "A, B", "duration_hours" => "not_a_float"},
          %{question: "Duration test", thread_id: thread2.id},
          ctx
        )

      {:ok, _, _} =
        CreatePoll.execute(
          %{"options" => "A, B", "duration_hours" => :bad_dur},
          %{question: "Duration test 2", thread_id: thread3.id},
          ctx
        )
    end

    test "AddVote, GetPollResults and ClosePoll execute full lifecycle" do
      user1 = create_user()
      user2 = create_user()
      {_forum, thread} = create_forum_and_thread(user1)
      ctx = make_ctx()

      {:ok, poll_res, _} =
        CreatePoll.execute(
          %{"options" => "Red, Blue, Green"},
          %{question: "Favorite color?", thread_id: thread.id, user_id: user1.id},
          ctx
        )

      poll_id = poll_res.poll_id

      # 1. AddVote tests
      assert %{type: "poll/add_vote"} = AddVote.schema()
      assert :ok = AddVote.validate_config(%{})

      # Success with atom keys
      {:ok, vote_res, u_ctx} =
        AddVote.execute(%{}, %{user_id: user1.id, poll_id: poll_id, option_index: 0}, ctx)

      assert vote_res.success == true
      assert vote_res.current_count == 1
      assert u_ctx.db_operations > ctx.db_operations

      # Second user voting with string keys
      {:ok, vote_res2, _} =
        AddVote.execute(
          %{},
          %{"user_id" => user2.id, "poll_id" => poll_id, "option_index" => 0},
          ctx
        )

      assert vote_res2.success == true
      assert vote_res2.current_count == 2

      # Same user voting again -> already_voted error
      {:error, dup_err, _} =
        AddVote.execute(%{}, %{user_id: user1.id, poll_id: poll_id, option_index: 0}, ctx)

      assert dup_err =~ "Failed to vote"

      # Invalid option_index
      {:error, opt_err, _} =
        AddVote.execute(
          %{},
          %{user_id: create_user().id, poll_id: poll_id, option_index: 99},
          ctx
        )

      assert opt_err =~ "Invalid option_index"

      # Nonexistent poll
      {:error, not_found_err, _} =
        AddVote.execute(
          %{},
          %{user_id: user1.id, poll_id: Ecto.UUID.generate(), option_index: 0},
          ctx
        )

      assert not_found_err =~ "Poll not found"

      # 2. GetPollResults tests
      assert %{type: "poll/get_poll_results"} = GetPollResults.schema()
      assert :ok = GetPollResults.validate_config(%{})

      {:ok, res_obj, _} = GetPollResults.execute(%{}, %{poll_id: poll_id}, ctx)
      assert res_obj.total_votes >= 2
      assert length(res_obj.results) == 3

      # GetPollResults for nonexistent poll
      {:ok, res_empty, _} =
        GetPollResults.execute(%{}, %{poll_id: Ecto.UUID.generate()}, ctx)

      assert res_empty.results == []
      assert res_empty.total_votes == 0

      # 3. ClosePoll tests
      assert %{type: "poll/close_poll"} = ClosePoll.schema()
      assert :ok = ClosePoll.validate_config(%{})

      {:ok, close_res, _} = ClosePoll.execute(%{}, %{poll_id: poll_id}, ctx)
      assert close_res.success == true
      assert close_res.winner == "Red"
      assert is_list(close_res.results)

      # Nonexistent poll close error
      {:error, close_err, _} =
        ClosePoll.execute(%{}, %{poll_id: Ecto.UUID.generate()}, ctx)

      assert close_err =~ "Failed to close poll"
    end

    test "CreatePrediction and ResolvePrediction execute and validate config" do
      user = create_user()
      ctx = make_ctx()

      assert %{type: "poll/create_prediction"} = CreatePrediction.schema()
      assert :ok = CreatePrediction.validate_config(%{"options" => "Yes, No"})
      assert {:error, _} = CreatePrediction.validate_config(%{"options" => ""})
      assert {:error, _} = CreatePrediction.validate_config(%{"options" => nil})
      assert {:error, _} = CreatePrediction.validate_config(%{"options" => "Single"})
      assert {:error, _} = CreatePrediction.validate_config(%{"options" => 1234})

      # Success with atom inputs and string closes_in_hours
      {:ok, pred_res, u_ctx} =
        CreatePrediction.execute(
          %{"options" => "Team A, Team B", "closes_in_hours" => "48.0"},
          %{question: "Who will win the match?", user_id: user.id},
          ctx
        )

      assert pred_res.success == true
      assert is_binary(pred_res.prediction_id)
      assert u_ctx.db_operations > ctx.db_operations

      # Success with string inputs and numeric closes_in_hours
      {:ok, pred_res2, _} =
        CreatePrediction.execute(
          %{"options" => "Up, Down", "closes_in_hours" => 24},
          %{"question" => "Market direction?", "user_id" => user.id},
          ctx
        )

      assert pred_res2.success == true

      # Error with less than 2 options
      {:error, err_opts, _} =
        CreatePrediction.execute(
          %{"options" => "Solo"},
          %{question: "Single?", user_id: user.id},
          ctx
        )

      assert err_opts =~ "at least 2 options"

      # Fallback non-number closes_in_hours
      {:ok, pred_res3, _} =
        CreatePrediction.execute(
          %{"options" => "A, B", "closes_in_hours" => :bad_val},
          %{question: "Fallback hours?", user_id: user.id},
          ctx
        )

      assert pred_res3.success == true

      # Fallback unparseable string closes_in_hours
      {:ok, pred_res4, _} =
        CreatePrediction.execute(
          %{"options" => "A, B", "closes_in_hours" => "not_a_float"},
          %{question: "Fallback str hours", user_id: user.id},
          ctx
        )

      assert pred_res4.success == true

      # Error on creation failure (missing title/user_id)
      {:error, pred_fail, _} =
        CreatePrediction.execute(
          %{"options" => "A, B"},
          %{question: nil, user_id: nil},
          make_ctx(%{triggered_by_id: nil})
        )

      assert pred_fail =~ "Failed to create prediction"

      # ResolvePrediction tests
      assert %{type: "poll/resolve_prediction"} = ResolvePrediction.schema()
      assert :ok = ResolvePrediction.validate_config(%{})

      # Success resolve with winning option
      {:ok, res_pred, _} =
        ResolvePrediction.execute(
          %{},
          %{prediction_id: pred_res.prediction_id, winning_option: "Team A"},
          ctx
        )

      assert res_pred.success == true

      # Resolve with string keys
      {:ok, res_pred2, _} =
        ResolvePrediction.execute(
          %{},
          %{"prediction_id" => pred_res2.prediction_id, "winning_option" => "Up"},
          ctx
        )

      assert res_pred2.success == true

      # Error: invalid winning option
      {:error, res_err, _} =
        ResolvePrediction.execute(
          %{},
          %{prediction_id: pred_res.prediction_id, winning_option: "NonExistentTeam"},
          ctx
        )

      assert res_err =~ "Failed to resolve prediction"

      # Error: nonexistent prediction_id
      {:error, res_err2, _} =
        ResolvePrediction.execute(
          %{},
          %{prediction_id: Ecto.UUID.generate(), winning_option: "Team A"},
          ctx
        )

      assert res_err2 =~ "Failed to resolve prediction"
    end

    test "CreateSuggestion and UpdateSuggestionStatus execute and validate config" do
      user = create_user()
      ctx = make_ctx()

      assert %{type: "poll/create_suggestion"} = CreateSuggestion.schema()
      assert :ok = CreateSuggestion.validate_config(%{})

      # Success with atom inputs
      {:ok, sugg_res, u_ctx} =
        CreateSuggestion.execute(
          %{"category" => "UI"},
          %{user_id: user.id, title: "Dark mode improvements", description: "Increase contrast"},
          ctx
        )

      assert sugg_res.success == true
      assert is_binary(sugg_res.suggestion_id)
      assert u_ctx.db_operations > ctx.db_operations

      # Success with string inputs
      {:ok, sugg_res2, _} =
        CreateSuggestion.execute(
          %{},
          %{"user_id" => user.id, "title" => "Search filters", "description" => "Add date range"},
          ctx
        )

      assert sugg_res2.success == true

      # Failure branch (missing title/description)
      {:error, sugg_err, _} =
        CreateSuggestion.execute(%{}, %{user_id: user.id, title: nil, description: nil}, ctx)

      assert sugg_err =~ "Failed to create suggestion"

      # UpdateSuggestionStatus tests
      assert %{type: "poll/update_suggestion_status"} = UpdateSuggestionStatus.schema()
      assert :ok = UpdateSuggestionStatus.validate_config(%{"status" => "planned"})
      assert {:error, _} = UpdateSuggestionStatus.validate_config(%{"status" => "invalid_stat"})

      # Success with atom inputs
      {:ok, upd_res, _} =
        UpdateSuggestionStatus.execute(
          %{"status" => "in_progress"},
          %{suggestion_id: sugg_res.suggestion_id},
          ctx
        )

      assert upd_res.success == true

      # Success with string inputs
      {:ok, upd_res2, _} =
        UpdateSuggestionStatus.execute(
          %{"status" => "done"},
          %{"suggestion_id" => sugg_res.suggestion_id},
          ctx
        )

      assert upd_res2.success == true

      # All mapped status transitions
      for st <- ~w(open planned declined pending) do
        {:ok, res, _} =
          UpdateSuggestionStatus.execute(
            %{"status" => st},
            %{suggestion_id: sugg_res.suggestion_id},
            ctx
          )

        assert res.success == true
      end

      # Error on nonexistent suggestion
      {:error, upd_err, _} =
        UpdateSuggestionStatus.execute(
          %{"status" => "done"},
          %{suggestion_id: Ecto.UUID.generate()},
          ctx
        )

      assert upd_err =~ "Failed to update suggestion"
    end
  end

  # ============================================================================
  # 4. SHOUTBOX NODES (8)
  # ============================================================================

  describe "Shoutbox nodes" do
    test "SendShout, PinShout, DeleteShout, GetShoutboxStats and ClearShoutbox execute lifecycle" do
      user = create_user()
      ctx = make_ctx()

      # 1. SendShout tests
      assert %{type: "shoutbox/send_shout"} = SendShout.schema()
      assert :ok = SendShout.validate_config(%{})

      # Success with atom inputs
      {:ok, shout1, u_ctx} =
        SendShout.execute(%{}, %{user_id: user.id, body: "Hello world!"}, ctx)

      assert shout1.success == true
      assert is_binary(shout1.message_id)
      assert u_ctx.db_operations > ctx.db_operations

      # Success with string inputs
      {:ok, shout2, _} =
        SendShout.execute(%{}, %{"user_id" => user.id, "body" => "Second shout"}, ctx)

      assert shout2.success == true

      # Failure branch (nil body)
      {:ok, shout_fail, _} =
        SendShout.execute(%{}, %{user_id: user.id, body: nil}, ctx)

      assert shout_fail.success == false
      assert is_nil(shout_fail.message_id)

      # 2. PinShout tests
      assert %{type: "shoutbox/pin_shout"} = PinShout.schema()
      assert :ok = PinShout.validate_config(%{})

      # Success with atom inputs
      {:ok, pin_res, _} = PinShout.execute(%{}, %{message_id: shout1.message_id}, ctx)
      assert pin_res.success == true

      # Success with string inputs
      {:ok, pin_res2, _} = PinShout.execute(%{}, %{"message_id" => shout2.message_id}, ctx)
      assert pin_res2.success == true

      # Nonexistent shout
      {:ok, pin_notfound, _} = PinShout.execute(%{}, %{message_id: Ecto.UUID.generate()}, ctx)
      assert pin_notfound.success == false

      # 3. GetShoutboxStats tests
      assert %{type: "shoutbox/get_shoutbox_stats"} = GetShoutboxStats.schema()
      assert :ok = GetShoutboxStats.validate_config(%{})

      {:ok, stats, _} = GetShoutboxStats.execute(%{}, %{}, ctx)
      assert stats.total_messages >= 2
      assert stats.messages_today >= 2
      assert stats.pinned_count >= 2

      # 4. DeleteShout tests
      assert %{type: "shoutbox/delete_shout"} = DeleteShout.schema()
      assert :ok = DeleteShout.validate_config(%{})

      # Success with atom inputs
      {:ok, del_res, _} = DeleteShout.execute(%{}, %{message_id: shout1.message_id}, ctx)
      assert del_res.success == true

      # Success with string inputs
      {:ok, del_res2, _} = DeleteShout.execute(%{}, %{"message_id" => shout2.message_id}, ctx)
      assert del_res2.success == true

      # Nonexistent shout
      {:ok, del_notfound, _} = DeleteShout.execute(%{}, %{message_id: Ecto.UUID.generate()}, ctx)
      assert del_notfound.success == false

      # 5. ClearShoutbox tests
      assert %{type: "shoutbox/clear_shoutbox"} = ClearShoutbox.schema()
      assert :ok = ClearShoutbox.validate_config(%{})

      {:ok, clear_res, _} = ClearShoutbox.execute(%{}, %{}, ctx)
      assert clear_res.success == true
      assert is_integer(clear_res.messages_cleared)
    end

    test "SendAnnouncement executes and validates config" do
      user = create_user()
      ctx = make_ctx()

      assert %{type: "shoutbox/send_announcement"} = SendAnnouncement.schema()

      assert :ok =
               SendAnnouncement.validate_config(%{"announcement_text" => "Maintenance at 10 PM"})

      assert {:error, _} = SendAnnouncement.validate_config(%{})
      assert {:error, _} = SendAnnouncement.validate_config(%{"announcement_text" => ""})
      assert {:error, _} = SendAnnouncement.validate_config(%{"announcement_text" => 1234})

      # Success with atom inputs
      {:ok, ann_res, u_ctx} =
        SendAnnouncement.execute(
          %{"announcement_text" => "Server update incoming"},
          %{user_id: user.id},
          ctx
        )

      assert ann_res.success == true
      assert is_binary(ann_res.message_id)
      assert u_ctx.db_operations > ctx.db_operations

      # Success with string inputs
      {:ok, ann_res2, _} =
        SendAnnouncement.execute(
          %{"announcement_text" => "Second notice"},
          %{"user_id" => user.id},
          ctx
        )

      assert ann_res2.success == true

      # Failure branch (nil user_id)
      {:ok, ann_fail, _} =
        SendAnnouncement.execute(
          %{"announcement_text" => "Notice"},
          %{user_id: nil},
          ctx
        )

      assert ann_fail.success == false
      assert is_nil(ann_fail.message_id)
    end

    test "MuteUserShoutbox executes and validates config" do
      user = create_user()
      ctx = make_ctx()

      assert %{type: "shoutbox/mute_user_shoutbox"} = MuteUserShoutbox.schema()
      assert :ok = MuteUserShoutbox.validate_config(%{"duration_seconds" => 600})
      assert {:error, _} = MuteUserShoutbox.validate_config(%{"duration_seconds" => -10})
      assert {:error, _} = MuteUserShoutbox.validate_config(%{"duration_seconds" => "invalid"})

      # Success with atom inputs
      {:ok, mute_res, u_ctx} =
        MuteUserShoutbox.execute(%{"duration_seconds" => 120}, %{user_id: user.id}, ctx)

      assert mute_res.success == true
      assert is_binary(mute_res.muted_until)
      assert u_ctx.db_operations > ctx.db_operations

      # Success with string inputs
      {:ok, mute_res2, _} =
        MuteUserShoutbox.execute(%{}, %{"user_id" => user.id}, ctx)

      assert mute_res2.success == true
    end

    test "ShoutboxCooldown branches between allowed and cooldown and validates config" do
      user = create_user()
      ctx = make_ctx()

      assert %{type: "shoutbox/shoutbox_cooldown"} = ShoutboxCooldown.schema()
      assert :ok = ShoutboxCooldown.validate_config(%{"cooldown_seconds" => 10})
      assert {:error, _} = ShoutboxCooldown.validate_config(%{"cooldown_seconds" => -5})
      assert {:error, _} = ShoutboxCooldown.validate_config(%{"cooldown_seconds" => "bad"})

      # First call -> allowed branch
      {:branch, "allowed", inputs_out, u_ctx} =
        ShoutboxCooldown.execute(%{"cooldown_seconds" => 10}, %{user_id: user.id}, ctx)

      assert inputs_out[:user_id] == user.id
      assert u_ctx.db_operations > ctx.db_operations

      # Second immediate call -> cooldown branch
      {:branch, "cooldown", _, _} =
        ShoutboxCooldown.execute(%{"cooldown_seconds" => 10}, %{"user_id" => user.id}, ctx)
    end
  end

  # ============================================================================
  # 5. REPUTATION NODES (6)
  # ============================================================================

  describe "Reputation nodes" do
    test "GiveReputation, GetReputation and CheckReputation execute full flow" do
      giver = create_user()
      receiver = create_user()
      ctx = make_ctx()

      # 1. GiveReputation tests
      assert %{type: "reputation/give_reputation"} = GiveReputation.schema()
      assert :ok = GiveReputation.validate_config(%{"type" => "positive", "amount" => 5})
      assert :ok = GiveReputation.validate_config(%{})
      assert {:error, _} = GiveReputation.validate_config(%{"type" => "neutral"})
      assert {:error, _} = GiveReputation.validate_config(%{"amount" => -1})

      # Positive rep with atom inputs
      {:ok, give_res, u_ctx} =
        GiveReputation.execute(
          %{"amount" => 10, "type" => "positive"},
          %{from_user_id: giver.id, to_user_id: receiver.id},
          ctx
        )

      assert give_res.success == true
      assert give_res.new_reputation == 10
      assert u_ctx.db_operations > ctx.db_operations

      # Negative rep with string inputs
      {:ok, give_res2, _} =
        GiveReputation.execute(
          %{"amount" => 2, "type" => "negative"},
          %{"from_user_id" => giver.id, "to_user_id" => receiver.id},
          ctx
        )

      assert give_res2.success == true
      assert give_res2.new_reputation == 8

      # Error branch (nil user)
      {:error, give_err, _} =
        GiveReputation.execute(%{}, %{from_user_id: nil, to_user_id: nil}, ctx)

      assert give_err =~ "Failed to give reputation"

      # 2. GetReputation tests
      assert %{type: "reputation/get_reputation"} = GetReputation.schema()
      assert :ok = GetReputation.validate_config(%{})

      # Success with atom inputs
      {:ok, get_res, _} = GetReputation.execute(%{}, %{user_id: receiver.id}, ctx)
      assert get_res.reputation == 8
      assert get_res.positive_count == 1
      assert get_res.negative_count == 1

      # Success with string inputs
      {:ok, get_res2, _} = GetReputation.execute(%{}, %{"user_id" => receiver.id}, ctx)
      assert get_res2.reputation == 8

      # Error branch (nonexistent user)
      {:error, get_err, _} = GetReputation.execute(%{}, %{user_id: Ecto.UUID.generate()}, ctx)
      assert get_err =~ "Failed to get reputation"

      # 3. CheckReputation tests
      assert %{type: "reputation/check_reputation"} = CheckReputation.schema()
      assert :ok = CheckReputation.validate_config(%{"threshold" => 5})
      assert :ok = CheckReputation.validate_config(%{})
      assert {:error, _} = CheckReputation.validate_config(%{"threshold" => "high"})

      # Above threshold branch
      {:branch, "above", rep_out, _} =
        CheckReputation.execute(%{"threshold" => 5}, %{user_id: receiver.id}, ctx)

      assert rep_out.reputation == 8

      # Below threshold branch
      {:branch, "below", rep_out2, _} =
        CheckReputation.execute(%{"threshold" => 20}, %{"user_id" => receiver.id}, ctx)

      assert rep_out2.reputation == 8

      # Error branch (nonexistent user)
      {:error, check_err, _} =
        CheckReputation.execute(%{}, %{user_id: Ecto.UUID.generate()}, ctx)

      assert check_err =~ "Failed to check reputation"
    end

    test "GetTradeRep executes and handles errors" do
      user = create_user()
      ctx = make_ctx()

      assert %{type: "reputation/get_trade_rep"} = GetTradeRep.schema()
      assert :ok = GetTradeRep.validate_config(%{})

      # Success with atom inputs
      {:ok, rep1, u_ctx} = GetTradeRep.execute(%{}, %{user_id: user.id}, ctx)
      assert rep1.trade_rep == 0
      assert rep1.successful_trades == 0
      assert rep1.total_trades == 0
      assert u_ctx.db_operations > ctx.db_operations

      # Success with string inputs
      {:ok, rep2, _} = GetTradeRep.execute(%{}, %{"user_id" => user.id}, ctx)
      assert rep2.trade_rep == 0

      # Error branch (missing user_id)
      {:error, rep_err, _} = GetTradeRep.execute(%{}, %{user_id: nil}, ctx)
      assert rep_err =~ "Failed to get trade reputation"
    end

    test "ReputationDecay executes and validates config" do
      ctx = make_ctx()

      assert %{type: "reputation/reputation_decay"} = ReputationDecay.schema()

      assert :ok =
               ReputationDecay.validate_config(%{"decay_percent" => 5.0, "inactive_days" => 14})

      assert :ok = ReputationDecay.validate_config(%{})
      assert {:error, _} = ReputationDecay.validate_config(%{"decay_percent" => 150})
      assert {:error, _} = ReputationDecay.validate_config(%{"decay_percent" => -1})
      assert {:error, _} = ReputationDecay.validate_config(%{"inactive_days" => 0})
      assert {:error, _} = ReputationDecay.validate_config(%{"inactive_days" => "two_weeks"})

      {:ok, res, u_ctx} =
        ReputationDecay.execute(
          %{"decay_percent" => 10.0, "inactive_days" => 60},
          %{},
          ctx
        )

      assert is_integer(res.users_affected)
      assert is_integer(res.total_decayed)
      assert u_ctx.db_operations > ctx.db_operations
    end

    test "ScaleRepPower calculates multiplier and handles input variations" do
      user = create_user()
      ctx = make_ctx()

      assert %{type: "reputation/scale_rep_power"} = ScaleRepPower.schema()
      assert :ok = ScaleRepPower.validate_config(%{})

      # Numeric base_amount
      {:ok, res, u_ctx} =
        ScaleRepPower.execute(%{}, %{user_id: user.id, base_amount: 100}, ctx)

      assert res.scaled_amount >= 10.0
      assert res.rep_multiplier >= 0.1
      assert u_ctx.db_operations > ctx.db_operations

      # String base_amount parsed
      {:ok, res2, _} =
        ScaleRepPower.execute(%{}, %{"user_id" => user.id, "base_amount" => "50.5"}, ctx)

      assert res2.scaled_amount > 0

      # Invalid string base_amount fallback
      {:ok, res3, _} =
        ScaleRepPower.execute(%{}, %{user_id: user.id, base_amount: "not_a_float"}, ctx)

      assert res3.scaled_amount > 0

      # Non-number/non-string base_amount fallback
      {:ok, res4, _} =
        ScaleRepPower.execute(%{}, %{user_id: user.id, base_amount: :bad_type}, ctx)

      assert res4.scaled_amount > 0

      # Error branch (nonexistent user)
      {:error, err, _} =
        ScaleRepPower.execute(%{}, %{user_id: Ecto.UUID.generate(), base_amount: 10}, ctx)

      assert err =~ "Failed to scale rep power"
    end
  end

  # ============================================================================
  # 6. STATS NODES (6)
  # ============================================================================

  describe "Stats nodes" do
    test "SetStat, GetStat, ModifyStat, GetAllStats, GetLevel and CheckStat execute full flow" do
      user = create_user()
      ctx = make_ctx()

      # 1. SetStat tests
      assert %{type: "stats/set_stat"} = SetStat.schema()
      assert :ok = SetStat.validate_config(%{})

      # Number value with atom keys
      {:ok, set_res, u_ctx} =
        SetStat.execute(%{}, %{user_id: user.id, stat_key: "strength", value: 15.0}, ctx)

      assert set_res.value == 15.0
      assert u_ctx.db_operations > ctx.db_operations

      # String value parsed with string keys
      {:ok, set_res2, _} =
        SetStat.execute(
          %{},
          %{"user_id" => user.id, "stat_key" => "agility", "value" => "20.5"},
          ctx
        )

      assert set_res2.value == 20.5

      # Invalid string value fallback
      {:ok, set_res3, _} =
        SetStat.execute(%{}, %{user_id: user.id, stat_key: "mana", value: "abc"}, ctx)

      assert set_res3.value == 0.0

      # Non-number/non-string value fallback
      {:ok, set_res4, _} =
        SetStat.execute(%{}, %{user_id: user.id, stat_key: "stamina", value: :bad}, ctx)

      assert set_res4.value == 0.0

      # Error branch (nil user_id)
      {:error, set_err, _} =
        SetStat.execute(%{}, %{user_id: nil, stat_key: nil, value: 10}, ctx)

      assert set_err =~ "Failed to set stat"

      # 2. GetStat tests
      assert %{type: "stats/get_stat"} = GetStat.schema()
      assert :ok = GetStat.validate_config(%{})

      {:ok, get_res, _} = GetStat.execute(%{}, %{user_id: user.id, stat_key: "strength"}, ctx)
      assert get_res.value == 15.0

      {:ok, get_res2, _} =
        GetStat.execute(%{}, %{"user_id" => user.id, "stat_key" => "agility"}, ctx)

      assert get_res2.value == 20.5

      # 3. ModifyStat tests
      assert %{type: "stats/modify_stat"} = ModifyStat.schema()
      assert :ok = ModifyStat.validate_config(%{})

      # Numeric delta
      {:ok, mod_res, _} =
        ModifyStat.execute(%{}, %{user_id: user.id, stat_key: "strength", delta: 5.0}, ctx)

      assert mod_res.old_value == 15.0
      assert mod_res.new_value == 20.0

      # String delta parsed
      {:ok, mod_res2, _} =
        ModifyStat.execute(
          %{},
          %{"user_id" => user.id, "stat_key" => "strength", "delta" => "-2.0"},
          ctx
        )

      assert mod_res2.old_value == 20.0
      assert mod_res2.new_value == 18.0

      # Invalid string delta fallback
      {:ok, mod_res3, _} =
        ModifyStat.execute(%{}, %{user_id: user.id, stat_key: "strength", delta: "bad"}, ctx)

      assert mod_res3.new_value == 18.0

      # Non-number/non-string delta fallback
      {:ok, mod_res4, _} =
        ModifyStat.execute(%{}, %{user_id: user.id, stat_key: "strength", delta: :bad}, ctx)

      assert mod_res4.new_value == 18.0

      # Error branch (nil user_id or stat_key)
      {:error, mod_err1, _} =
        ModifyStat.execute(%{}, %{user_id: nil, stat_key: nil, delta: 10}, ctx)

      assert mod_err1 =~ "user_id and stat_key are required"

      # Error branch (foreign key constraint violation via random UUID)
      {:error, mod_err2, _} =
        ModifyStat.execute(
          %{},
          %{user_id: Ecto.UUID.generate(), stat_key: "strength", delta: 10},
          ctx
        )

      assert mod_err2 =~ "Failed to modify stat"

      # 4. GetAllStats tests
      assert %{type: "stats/get_all_stats"} = GetAllStats.schema()
      assert :ok = GetAllStats.validate_config(%{})

      {:ok, all_res, _} = GetAllStats.execute(%{}, %{user_id: user.id}, ctx)
      assert all_res.count >= 4
      assert Map.has_key?(all_res.stats, "strength")
      assert Map.has_key?(all_res.stats, "agility")

      # 5. GetLevel tests
      assert %{type: "stats/get_level"} = GetLevel.schema()
      assert :ok = GetLevel.validate_config(%{"formula" => "linear"})
      assert :ok = GetLevel.validate_config(%{"formula" => "sqrt"})
      assert :ok = GetLevel.validate_config(%{"formula" => "exponential"})
      assert {:error, _} = GetLevel.validate_config(%{"formula" => "quadratic"})

      # User with 0 xp -> level 1
      {:ok, lvl_res, _} = GetLevel.execute(%{}, %{user_id: user.id}, ctx)
      assert lvl_res.level == 1

      # Set xp and check level
      UserStats.set_stat(user.id, "xp", 500)
      {:ok, lvl_res2, _} = GetLevel.execute(%{}, %{"user_id" => user.id}, ctx)
      assert lvl_res2.level >= 2

      # 6. CheckStat tests
      assert %{type: "stats/check_stat"} = CheckStat.schema()
      assert :ok = CheckStat.validate_config(%{"operator" => "gte", "threshold" => 10})
      assert :ok = CheckStat.validate_config(%{})
      assert {:error, _} = CheckStat.validate_config(%{"operator" => "not_op"})
      assert {:error, _} = CheckStat.validate_config(%{"threshold" => "ten"})

      # Branch true
      {:branch, "true", check_out, _} =
        CheckStat.execute(
          %{"threshold" => 10},
          %{user_id: user.id, stat_key: "strength"},
          ctx
        )

      assert check_out.result == true
      assert check_out.value == 18.0

      # Branch false
      {:branch, "false", check_out2, _} =
        CheckStat.execute(
          %{"threshold" => 50},
          %{"user_id" => user.id, "stat_key" => "strength"},
          ctx
        )

      assert check_out2.result == false
    end
  end

  # ============================================================================
  # 7. DB LIMIT TESTS ACROSS COMMUNITY NODES
  # ============================================================================

  describe "Database limit exhaustion across community nodes" do
    test "All 44 community nodes raise when DB limit is exceeded" do
      ctx = make_ctx(%{db_operations: 100, max_db_ops: 50})

      inputs = %{
        user_id: "u",
        ticket_id: "t",
        tournament_id: "tour",
        poll_id: "p",
        match_id: "m",
        message_id: "msg",
        prediction_id: "pr",
        suggestion_id: "sg",
        stat_key: "k",
        from_user_id: "f",
        to_user_id: "to"
      }

      nodes = [
        # Ticket (8)
        AddInternalNote,
        AssignTicket,
        ClaimTicket,
        CloseWithRating,
        CreateTicket,
        EscalateTicket,
        TicketSlaCheck,
        UpdateTicketStatus,
        # Tournament (8)
        AdvanceBracket,
        AwardPlacement,
        CreateSeason,
        CreateTournament,
        GetMatchup,
        GetStandings,
        RegisterParticipant,
        SubmitResult,
        # Poll (8)
        AddVote,
        ClosePoll,
        CreatePoll,
        CreatePrediction,
        CreateSuggestion,
        GetPollResults,
        ResolvePrediction,
        UpdateSuggestionStatus,
        # Shoutbox (8)
        ClearShoutbox,
        DeleteShout,
        GetShoutboxStats,
        MuteUserShoutbox,
        PinShout,
        SendAnnouncement,
        SendShout,
        ShoutboxCooldown,
        # Reputation (6)
        CheckReputation,
        GetReputation,
        GetTradeRep,
        GiveReputation,
        ReputationDecay,
        ScaleRepPower,
        # Stats (6)
        CheckStat,
        GetAllStats,
        GetLevel,
        GetStat,
        ModifyStat,
        SetStat
      ]

      for node <- nodes do
        assert_raise ForgeNexus.Plugins.Engine.SandboxError,
                     ~r/Database operation limit reached/,
                     fn ->
                       node.execute(%{}, inputs, ctx)
                     end
      end
    end
  end
end
