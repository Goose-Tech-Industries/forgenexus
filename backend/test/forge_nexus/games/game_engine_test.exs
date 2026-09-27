defmodule ForgeNexus.Games.GameEngineTest do
  use ForgeNexus.DataCase, async: false

  alias ForgeNexus.Games.GameEngine
  alias ForgeNexus.{Accounts, Communities, Repo}
  alias ForgeNexus.Games.PartyGame

  defp create_user do
    uid = System.unique_integer([:positive])

    {:ok, user} =
      Accounts.register_user(%{
        username: "game_u_#{uid}",
        email: "game_u_#{uid}@example.com",
        password: "ValidPassword123!@#"
      })

    user
  end

  defp create_community(user) do
    uid = System.unique_integer([:positive])

    {:ok, comm} =
      Communities.create_community(%{
        name: "Game Comm #{uid}",
        slug: "game-comm-#{uid}",
        owner_id: user.id
      })

    comm
  end

  defp create_room(community, user) do
    uid = System.unique_integer([:positive])
    room_id = Ecto.UUID.generate()
    {:ok, room_bin} = Ecto.UUID.dump(room_id)
    {:ok, comm_bin} = Ecto.UUID.dump(community.id)
    {:ok, user_bin} = Ecto.UUID.dump(user.id)
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

    Repo.insert_all("voice_rooms", [
      %{
        id: room_bin,
        community_id: comm_bin,
        created_by_id: user_bin,
        name: "Game Room #{uid}",
        slug: "game-room-#{uid}",
        type: "lounge",
        is_active: true,
        inserted_at: now,
        updated_at: now
      }
    ])

    room_id
  end

  describe "create_game/1 and get_game!/1" do
    test "creates and fetches a party game" do
      user = create_user()
      comm = create_community(user)

      attrs = %{
        game_type: "trivia",
        community_id: comm.id,
        host_id: user.id,
        max_players: 8,
        total_rounds: 3
      }

      assert {:ok, %PartyGame{} = game} = GameEngine.create_game(attrs)
      assert game.game_type == "trivia"
      assert game.status == "lobby"

      fetched = GameEngine.get_game!(game.id)
      assert fetched.id == game.id
    end
  end

  describe "join_game/2" do
    test "allows players to join in lobby and enforces room limits and status" do
      user1 = create_user()
      user2 = create_user()
      user3 = create_user()
      comm = create_community(user1)
      room_id = create_room(comm, user1)

      {:ok, game} =
        GameEngine.create_game(%{
          game_type: "cards_against_humanity",
          community_id: comm.id,
          room_id: room_id,
          host_id: user1.id,
          max_players: 2
        })

      # Join first player
      assert {:ok, joined_game} = GameEngine.join_game(game.id, user1.id)
      assert joined_game.id == game.id

      # Duplicate join (on_conflict: :nothing)
      assert {:ok, _} = GameEngine.join_game(game.id, user1.id)

      # Join second player
      assert {:ok, _} = GameEngine.join_game(game.id, user2.id)

      # Game is full
      assert GameEngine.join_game(game.id, user3.id) == {:error, :game_full}

      # Game in progress
      Repo.update_all(
        from(g in "party_games", where: g.id == type(^game.id, :binary_id)),
        set: [status: "playing"]
      )

      assert GameEngine.join_game(game.id, user3.id) == {:error, :game_in_progress}
    end
  end

  describe "start_game/2" do
    test "verifies host and initializes game states for all supported game types" do
      user1 = create_user()
      user2 = create_user()
      comm = create_community(user1)
      room_id = create_room(comm, user1)

      {:ok, game} =
        GameEngine.create_game(%{
          game_type: "cards_against_humanity",
          community_id: comm.id,
          room_id: room_id,
          host_id: user1.id
        })

      # Non-host cannot start
      assert GameEngine.start_game(game.id, user2.id) == {:error, :not_host}

      # Host starts game
      assert {:ok, started} = GameEngine.start_game(game.id, user1.id)
      assert started.status == "playing"
      assert started.round_number == 1
      assert is_binary(started.state["prompt"])
      assert started.state["phase"] == "answering"

      # Start game without room_id (no broadcast)
      {:ok, game_no_room} =
        GameEngine.create_game(%{
          game_type: "cards_against_humanity",
          community_id: comm.id,
          host_id: user1.id
        })

      assert {:ok, _} = GameEngine.start_game(game_no_room.id, user1.id)

      # Test initializations for each game type
      # Trivia with default questions
      {:ok, g_trivia} =
        GameEngine.create_game(%{game_type: "trivia", community_id: comm.id, host_id: user1.id})

      {:ok, started_trivia} = GameEngine.start_game(g_trivia.id, user1.id)
      assert length(started_trivia.state["questions"]) == 5

      # Trivia with custom questions
      custom_q = [%{"question" => "Q1", "answer" => "A1"}]

      {:ok, g_trivia_custom} =
        GameEngine.create_game(%{
          game_type: "trivia",
          settings: %{"questions" => custom_q},
          community_id: comm.id,
          host_id: user1.id
        })

      {:ok, started_trivia_custom} = GameEngine.start_game(g_trivia_custom.id, user1.id)
      assert started_trivia_custom.state["questions"] == custom_q

      # Would you rather
      {:ok, g_wyr} =
        GameEngine.create_game(%{
          game_type: "would_you_rather",
          community_id: comm.id,
          host_id: user1.id
        })

      {:ok, started_wyr} = GameEngine.start_game(g_wyr.id, user1.id)
      assert is_binary(started_wyr.state["question"])
      assert started_wyr.state["phase"] == "voting"

      # Hot takes
      {:ok, g_hot} =
        GameEngine.create_game(%{
          game_type: "hot_takes",
          community_id: comm.id,
          host_id: user1.id
        })

      {:ok, started_hot} = GameEngine.start_game(g_hot.id, user1.id)
      assert is_binary(started_hot.state["statement"])
      assert started_hot.state["phase"] == "voting"

      # Word chain
      {:ok, g_wc} =
        GameEngine.create_game(%{
          game_type: "word_chain",
          community_id: comm.id,
          host_id: user1.id
        })

      {:ok, started_wc} = GameEngine.start_game(g_wc.id, user1.id)
      assert started_wc.state["chain"] == []

      # Story builder
      {:ok, g_sb} =
        GameEngine.create_game(%{
          game_type: "story_builder",
          community_id: comm.id,
          host_id: user1.id
        })

      {:ok, started_sb} = GameEngine.start_game(g_sb.id, user1.id)
      assert started_sb.state["sentences"] == []

      # Mafia
      {:ok, g_mafia} =
        GameEngine.create_game(%{game_type: "mafia", community_id: comm.id, host_id: user1.id})

      {:ok, started_mafia} = GameEngine.start_game(g_mafia.id, user1.id)
      assert started_mafia.state["phase"] == "night"

      # Drawing guess (fallback game type)
      {:ok, g_fallback} =
        GameEngine.create_game(%{
          game_type: "drawing_guess",
          community_id: comm.id,
          host_id: user1.id
        })

      {:ok, started_fallback} = GameEngine.start_game(g_fallback.id, user1.id)
      assert started_fallback.state == %{}

      # Update error handling branch (when Repo.update fails validation)
      bad_game_id = Ecto.UUID.generate()
      {:ok, bad_bin} = Ecto.UUID.dump(bad_game_id)
      {:ok, comm_bin} = Ecto.UUID.dump(comm.id)
      {:ok, u_bin} = Ecto.UUID.dump(user1.id)
      now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

      Repo.insert_all("party_games", [
        %{
          id: bad_bin,
          community_id: comm_bin,
          host_id: u_bin,
          game_type: "",
          status: "lobby",
          max_players: 5,
          round_number: 0,
          total_rounds: 5,
          inserted_at: now,
          updated_at: now
        }
      ])

      assert {:error, %Ecto.Changeset{}} = GameEngine.start_game(bad_game_id, user1.id)
    end
  end

  describe "submit_answer/3 and process_answer" do
    test "processes answers and advances rounds when all answered" do
      user1 = create_user()
      user2 = create_user()
      comm = create_community(user1)
      room_id = create_room(comm, user1)

      {:ok, game} =
        GameEngine.create_game(%{
          game_type: "trivia",
          community_id: comm.id,
          room_id: room_id,
          host_id: user1.id,
          total_rounds: 3
        })

      # Submit when not playing
      assert GameEngine.submit_answer(game.id, user1.id, "2007") == {:error, :not_playing}

      # Join players while in lobby, then start game
      {:ok, _} = GameEngine.join_game(game.id, user1.id)
      {:ok, _} = GameEngine.join_game(game.id, user2.id)
      {:ok, game} = GameEngine.start_game(game.id, user1.id)

      # Trivia answer submission: user1 answers correct ("2007"), user2 answers incorrect ("2005")
      # First submission triggers all_answered? and advances round
      {:ok, _updated_game} = GameEngine.submit_answer(game.id, user1.id, "2007")
      # Round advanced from 1 to 2 in database
      assert GameEngine.get_game!(game.id).round_number == 2

      # Process answers for cards_against_humanity
      {:ok, g_cah_ans} =
        GameEngine.create_game(%{
          game_type: "cards_against_humanity",
          community_id: comm.id,
          host_id: user1.id
        })

      {:ok, g_cah_ans} = GameEngine.start_game(g_cah_ans.id, user1.id)
      {:ok, g_cah_ans} = GameEngine.submit_answer(g_cah_ans.id, user1.id, "hilarious answer")
      assert g_cah_ans.state["answers"][user1.id] == "hilarious answer"

      # Process answers for would_you_rather
      {:ok, g_wyr} =
        GameEngine.create_game(%{
          game_type: "would_you_rather",
          community_id: comm.id,
          host_id: user1.id
        })

      {:ok, g_wyr} = GameEngine.start_game(g_wyr.id, user1.id)
      {:ok, g_wyr} = GameEngine.submit_answer(g_wyr.id, user1.id, "option_a")
      assert g_wyr.state["votes"][user1.id] == "option_a"

      # Process answers for hot_takes
      {:ok, g_hot} =
        GameEngine.create_game(%{
          game_type: "hot_takes",
          community_id: comm.id,
          host_id: user1.id
        })

      {:ok, g_hot} = GameEngine.start_game(g_hot.id, user1.id)
      {:ok, g_hot} = GameEngine.submit_answer(g_hot.id, user1.id, "agree")
      assert g_hot.state["votes"][user1.id] == "agree"

      # Process answers for word_chain (both initial and subsequent words)
      {:ok, g_wc} =
        GameEngine.create_game(%{
          game_type: "word_chain",
          community_id: comm.id,
          host_id: user1.id
        })

      {:ok, g_wc} = GameEngine.start_game(g_wc.id, user1.id)
      {:ok, g_wc} = GameEngine.submit_answer(g_wc.id, user1.id, "apple")
      assert g_wc.state["chain"] == ["apple"]
      {:ok, g_wc} = GameEngine.submit_answer(g_wc.id, user2.id, "elephant")
      assert g_wc.state["chain"] == ["apple", "elephant"]

      # Process answers for story_builder (both initial and subsequent sentences)
      {:ok, g_sb} =
        GameEngine.create_game(%{
          game_type: "story_builder",
          community_id: comm.id,
          host_id: user1.id
        })

      {:ok, g_sb} = GameEngine.start_game(g_sb.id, user1.id)
      {:ok, g_sb} = GameEngine.submit_answer(g_sb.id, user1.id, "Once upon a time.")
      assert g_sb.state["sentences"] == ["Once upon a time."]
      {:ok, g_sb} = GameEngine.submit_answer(g_sb.id, user2.id, "There was an adventurer.")
      assert g_sb.state["sentences"] == ["Once upon a time.", "There was an adventurer."]

      # Process answers for fallback game_type (drawing_guess)
      {:ok, g_dg} =
        GameEngine.create_game(%{
          game_type: "drawing_guess",
          community_id: comm.id,
          host_id: user1.id
        })

      {:ok, g_dg} = GameEngine.start_game(g_dg.id, user1.id)
      {:ok, g_dg} = GameEngine.submit_answer(g_dg.id, user1.id, "cat")
      assert g_dg.state["answers"][user1.id] == "cat"

      # Update error handling branch for submit_answer
      bad_game_id = Ecto.UUID.generate()
      {:ok, bad_bin} = Ecto.UUID.dump(bad_game_id)
      {:ok, comm_bin} = Ecto.UUID.dump(comm.id)
      {:ok, u_bin} = Ecto.UUID.dump(user1.id)
      now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

      Repo.insert_all("party_games", [
        %{
          id: bad_bin,
          community_id: comm_bin,
          host_id: u_bin,
          game_type: "",
          status: "playing",
          max_players: 5,
          round_number: 1,
          total_rounds: 5,
          inserted_at: now,
          updated_at: now
        }
      ])

      assert {:error, %Ecto.Changeset{}} =
               GameEngine.submit_answer(bad_game_id, user1.id, "answer")
    end
  end

  describe "end_round/1, next_round_state, and game_over with prize distribution" do
    test "handles round transitions and distributes prizes on game_over" do
      user1 = create_user()
      user2 = create_user()
      comm = create_community(user1)
      room_id = create_room(comm, user1)

      # 1. Round transitions for cards_against_humanity
      {:ok, g_cah} =
        GameEngine.create_game(%{
          game_type: "cards_against_humanity",
          community_id: comm.id,
          room_id: room_id,
          host_id: user1.id,
          total_rounds: 3
        })

      {:ok, g_cah} = GameEngine.start_game(g_cah.id, user1.id)
      GameEngine.end_round(g_cah)
      reloaded_cah = GameEngine.get_game!(g_cah.id)
      assert reloaded_cah.round_number == 2
      assert reloaded_cah.state["phase"] == "answering"

      # 2. Round transitions for would_you_rather
      {:ok, g_wyr} =
        GameEngine.create_game(%{
          game_type: "would_you_rather",
          community_id: comm.id,
          host_id: user1.id,
          total_rounds: 3
        })

      {:ok, g_wyr} = GameEngine.start_game(g_wyr.id, user1.id)
      GameEngine.end_round(g_wyr)
      reloaded_wyr = GameEngine.get_game!(g_wyr.id)
      assert reloaded_wyr.round_number == 2
      assert reloaded_wyr.state["votes"] == %{}

      # 3. Round transitions for hot_takes
      {:ok, g_hot} =
        GameEngine.create_game(%{
          game_type: "hot_takes",
          community_id: comm.id,
          host_id: user1.id,
          total_rounds: 3
        })

      {:ok, g_hot} = GameEngine.start_game(g_hot.id, user1.id)
      GameEngine.end_round(g_hot)
      reloaded_hot = GameEngine.get_game!(g_hot.id)
      assert reloaded_hot.round_number == 2
      assert reloaded_hot.state["votes"] == %{}

      # 4. Round transitions for fallback game type (drawing_guess)
      {:ok, g_dg} =
        GameEngine.create_game(%{
          game_type: "drawing_guess",
          community_id: comm.id,
          host_id: user1.id,
          total_rounds: 3
        })

      {:ok, g_dg} = GameEngine.start_game(g_dg.id, user1.id)
      GameEngine.end_round(g_dg)
      reloaded_dg = GameEngine.get_game!(g_dg.id)
      assert reloaded_dg.round_number == 2

      # 5. Game Over with Wager and prize distribution
      {:ok, g_wager} =
        GameEngine.create_game(%{
          game_type: "trivia",
          community_id: comm.id,
          room_id: room_id,
          host_id: user1.id,
          total_rounds: 1,
          wager_enabled: true,
          wager_per_round: 25
        })

      {:ok, _} = GameEngine.join_game(g_wager.id, user1.id)
      {:ok, _} = GameEngine.join_game(g_wager.id, user2.id)
      {:ok, g_wager} = GameEngine.start_game(g_wager.id, user1.id)

      # Give user1 points for correct answer, user2 wrong answer
      g_wager = %{
        g_wager
        | state:
            Map.put(g_wager.state, "answers", %{
              user1.id => "2007",
              user2.id => "2005"
            })
      }

      initial_pts = Accounts.get_user!(user1.id).points
      GameEngine.end_round(g_wager)

      game_over = GameEngine.get_game!(g_wager.id)
      assert game_over.status == "game_over"

      final_scores = GameEngine.get_scores(g_wager.id)
      assert length(final_scores) == 2
      # Winner user1 received points in economy
      updated_pts = Accounts.get_user!(user1.id).points
      assert updated_pts > initial_pts

      # 6. Game Over with Wager but empty scores list
      {:ok, g_empty_wager} =
        GameEngine.create_game(%{
          game_type: "trivia",
          community_id: comm.id,
          host_id: user1.id,
          total_rounds: 1,
          wager_enabled: true,
          wager_per_round: 25
        })

      {:ok, g_empty_wager} = GameEngine.start_game(g_empty_wager.id, user1.id)
      # No players joined
      GameEngine.end_round(g_empty_wager)
      assert GameEngine.get_game!(g_empty_wager.id).status == "game_over"
    end
  end

  describe "pick_random_prompt/1" do
    test "returns random prompts for known types and default prompt for fallback" do
      assert is_binary(GameEngine.pick_random_prompt("cah"))
      assert is_binary(GameEngine.pick_random_prompt("wyr"))
      assert is_binary(GameEngine.pick_random_prompt("hot_take"))
      assert GameEngine.pick_random_prompt("unknown_type") == "Default prompt"
    end
  end
end
