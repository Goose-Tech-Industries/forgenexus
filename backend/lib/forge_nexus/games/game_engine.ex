defmodule ForgeNexus.Games.GameEngine do
  @moduledoc """
  State machine for party games in voice rooms. Manages game lifecycle
  (lobby → playing → round_end → game_over), player management, scoring,
  and real-time broadcasting of game state via Phoenix channels.

  ## Supported games

    * `cards_against_humanity` — judge picks best combo from player submissions
    * `trivia` — host reads questions, players buzz in or pick from options
    * `would_you_rather` — binary choice, see how the room splits
    * `drawing_guess` — one player describes, others guess (text-based)
    * `word_chain` — each player adds a word, timer ticks down
    * `story_builder` — each player adds a sentence to a collaborative story
    * `hot_takes` — post a statement, room votes agree/disagree
    * `mafia` — social deduction with day/night phases

  Game state is stored in the `party_games.state` JSONB column and
  broadcast to all players via `voice:ROOM_ID` channel events prefixed
  with `game:`.
  """

  import Ecto.Query
  alias ForgeNexus.Repo
  alias ForgeNexus.Games.PartyGame

  def create_game(attrs) do
    %PartyGame{} |> PartyGame.changeset(attrs) |> Repo.insert()
  end

  def get_game!(id), do: Repo.get!(PartyGame, id)

  def join_game(game_id, user_id) do
    game = get_game!(game_id)

    if game.status != "lobby" do
      {:error, :game_in_progress}
    else
      player_count =
        from(p in "party_game_players", where: p.game_id == ^game_id, select: count())
        |> Repo.one()

      if player_count >= game.max_players do
        {:error, :game_full}
      else
        Repo.insert_all(
          "party_game_players",
          [
            %{
              id: Ecto.UUID.generate(),
              game_id: game_id,
              user_id: user_id,
              score: 0,
              is_active: true,
              inserted_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second),
              updated_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
            }
          ],
          on_conflict: :nothing
        )

        broadcast_game_event(game, "player_joined", %{user_id: user_id})
        {:ok, game}
      end
    end
  end

  def start_game(game_id, host_id) do
    game = get_game!(game_id)

    if game.host_id != host_id do
      {:error, :not_host}
    else
      initial_state = initialize_game_state(game.game_type, game.settings)

      game
      |> PartyGame.changeset(%{status: "playing", round_number: 1, state: initial_state})
      |> Repo.update()
      |> case do
        {:ok, game} ->
          broadcast_game_event(game, "game_started", %{
            game_type: game.game_type,
            round: 1,
            state: public_state(game)
          })

          {:ok, game}

        error ->
          error
      end
    end
  end

  def submit_answer(game_id, user_id, answer) do
    game = get_game!(game_id)

    if game.status != "playing" do
      {:error, :not_playing}
    else
      new_state = process_answer(game.game_type, game.state, user_id, answer)

      game
      |> PartyGame.changeset(%{state: new_state})
      |> Repo.update()
      |> case do
        {:ok, game} ->
          broadcast_game_event(game, "answer_submitted", %{user_id: user_id})

          if all_answered?(game.game_type, new_state) do
            end_round(game)
          end

          {:ok, game}

        error ->
          error
      end
    end
  end

  def end_round(game) do
    results = calculate_round_results(game.game_type, game.state)
    update_scores(game.id, results.score_changes)

    new_round = game.round_number + 1

    if new_round > game.total_rounds do
      game
      |> PartyGame.changeset(%{
        status: "game_over",
        state: Map.put(game.state, "results", results)
      })
      |> Repo.update()

      final_scores = get_scores(game.id)

      if game.wager_enabled and game.wager_per_round > 0 do
        distribute_prizes(game, final_scores)
      end

      broadcast_game_event(game, "game_over", %{final_scores: final_scores, results: results})
    else
      next_state = next_round_state(game.game_type, game.state, new_round)

      game
      |> PartyGame.changeset(%{status: "playing", round_number: new_round, state: next_state})
      |> Repo.update()

      broadcast_game_event(game, "new_round", %{round: new_round, state: next_state})
    end
  end

  def get_scores(game_id) do
    from(p in "party_game_players",
      where: p.game_id == ^game_id,
      order_by: [desc: :score],
      select: %{user_id: p.user_id, score: p.score}
    )
    |> Repo.all()
  end

  defp update_scores(game_id, changes) when is_map(changes) do
    Enum.each(changes, fn {user_id, delta} ->
      from(p in "party_game_players",
        where: p.game_id == ^game_id and p.user_id == ^user_id
      )
      |> Repo.update_all(inc: [score: delta])
    end)
  end

  defp distribute_prizes(game, scores) do
    total_pool = length(scores) * game.wager_per_round * game.total_rounds

    case scores do
      [first | _] ->
        ForgeNexus.Economy.award_points(first.user_id, "game_winner",
          amount: total_pool,
          description: "Won #{game.game_type} game"
        )

      _ ->
        :ok
    end
  end

  defp broadcast_game_event(game, event, payload) do
    if game.room_id do
      ForgeNexusWeb.Endpoint.broadcast("voice:#{game.room_id}", "game:#{event}", payload)
    end
  end

  defp public_state(game) do
    Map.drop(game.state, ["answers", "secret"])
  end

  defp initialize_game_state("cards_against_humanity", _settings) do
    %{
      "prompt" => pick_random_prompt("cah"),
      "answers" => %{},
      "judge_id" => nil,
      "phase" => "answering"
    }
  end

  defp initialize_game_state("trivia", settings) do
    questions = Map.get(settings, "questions") || default_trivia()
    %{"questions" => questions, "current_question" => 0, "answers" => %{}, "buzzes" => []}
  end

  defp initialize_game_state("would_you_rather", _) do
    %{"question" => pick_random_prompt("wyr"), "votes" => %{}, "phase" => "voting"}
  end

  defp initialize_game_state("hot_takes", _) do
    %{"statement" => pick_random_prompt("hot_take"), "votes" => %{}, "phase" => "voting"}
  end

  defp initialize_game_state("word_chain", _) do
    %{"chain" => [], "current_player_index" => 0, "timer_seconds" => 10}
  end

  defp initialize_game_state("story_builder", _) do
    %{"sentences" => [], "current_player_index" => 0}
  end

  defp initialize_game_state("mafia", _) do
    %{"phase" => "night", "alive" => [], "roles" => %{}, "votes" => %{}}
  end

  defp initialize_game_state(_, _), do: %{}

  defp process_answer("cards_against_humanity", state, user_id, answer) do
    put_in(state, ["answers", user_id], answer)
  end

  defp process_answer("trivia", state, user_id, answer) do
    put_in(state, ["answers", user_id], answer)
  end

  defp process_answer("would_you_rather", state, user_id, answer) do
    put_in(state, ["votes", user_id], answer)
  end

  defp process_answer("hot_takes", state, user_id, answer) do
    put_in(state, ["votes", user_id], answer)
  end

  defp process_answer("word_chain", state, _user_id, word) do
    Map.update(state, "chain", [word], fn chain -> chain ++ [word] end)
  end

  defp process_answer("story_builder", state, _user_id, sentence) do
    Map.update(state, "sentences", [sentence], fn s -> s ++ [sentence] end)
  end

  defp process_answer(_, state, user_id, answer) do
    put_in(state, ["answers", user_id], answer)
  end

  defp all_answered?("cards_against_humanity", state), do: map_size(state["answers"] || %{}) > 0
  defp all_answered?("trivia", state), do: map_size(state["answers"] || %{}) > 0
  defp all_answered?(_, _), do: false

  defp calculate_round_results("trivia", state) do
    correct =
      state["questions"] |> Enum.at(state["current_question"] || 0, %{}) |> Map.get("answer")

    changes =
      Enum.reduce(state["answers"] || %{}, %{}, fn {uid, ans}, acc ->
        if ans == correct, do: Map.put(acc, uid, 10), else: acc
      end)

    %{score_changes: changes, correct_answer: correct}
  end

  defp calculate_round_results(_, _state), do: %{score_changes: %{}}

  defp next_round_state("trivia", state, round) do
    %{state | "current_question" => round - 1, "answers" => %{}, "buzzes" => []}
  end

  defp next_round_state("cards_against_humanity", _state, _round) do
    %{"prompt" => pick_random_prompt("cah"), "answers" => %{}, "phase" => "answering"}
  end

  defp next_round_state("would_you_rather", _state, _round) do
    %{"question" => pick_random_prompt("wyr"), "votes" => %{}, "phase" => "voting"}
  end

  defp next_round_state("hot_takes", _state, _round) do
    %{"statement" => pick_random_prompt("hot_take"), "votes" => %{}, "phase" => "voting"}
  end

  defp next_round_state(_, state, _), do: Map.put(state, "answers", %{})

  defp pick_random_prompt("cah") do
    Enum.random([
      "The worst thing to say at a funeral is ____.",
      "Instead of a trophy, the winner gets ____.",
      "The secret to a happy life is ____.",
      "My guilty pleasure is ____.",
      "____ is the new ____."
    ])
  end

  defp pick_random_prompt("wyr") do
    Enum.random([
      "Would you rather have unlimited money or unlimited free time?",
      "Would you rather be able to teleport or read minds?",
      "Would you rather live without music or without movies?",
      "Would you rather always be 10 minutes late or 20 minutes early?",
      "Would you rather have a personal chef or a personal trainer?"
    ])
  end

  defp pick_random_prompt("hot_take") do
    Enum.random([
      "Pineapple belongs on pizza.",
      "The last season was actually good.",
      "Morning people are more productive.",
      "Cats are better than dogs.",
      "The original is always better than the remake."
    ])
  end

  defp pick_random_prompt(_), do: "Default prompt"

  defp default_trivia do
    [
      %{
        "question" => "What year was the first iPhone released?",
        "options" => ["2005", "2006", "2007", "2008"],
        "answer" => "2007"
      },
      %{
        "question" => "What is the capital of Australia?",
        "options" => ["Sydney", "Melbourne", "Canberra", "Brisbane"],
        "answer" => "Canberra"
      },
      %{
        "question" => "How many sides does a hexagon have?",
        "options" => ["5", "6", "7", "8"],
        "answer" => "6"
      },
      %{
        "question" => "What element has the chemical symbol 'Au'?",
        "options" => ["Silver", "Gold", "Aluminum", "Argon"],
        "answer" => "Gold"
      },
      %{
        "question" => "Who painted the Mona Lisa?",
        "options" => ["Michelangelo", "Da Vinci", "Raphael", "Donatello"],
        "answer" => "Da Vinci"
      }
    ]
  end
end
