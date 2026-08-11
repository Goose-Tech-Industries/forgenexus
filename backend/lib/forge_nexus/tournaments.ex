defmodule ForgeNexus.Tournaments do
  @moduledoc "Tournament brackets, matchmaking, and standings."
  import Ecto.Query
  alias ForgeNexus.Repo
  alias ForgeNexus.Tournaments.{Tournament, Participant, Match}

  def create_tournament(attrs), do: %Tournament{} |> Tournament.changeset(attrs) |> Repo.insert()

  def get_tournament!(id),
    do: Repo.get!(Tournament, id) |> Repo.preload([:participants, :matches])

  def register_participant(tournament_id, user_id) do
    tournament = Repo.get!(Tournament, tournament_id)

    participant_count =
      Repo.one(
        from p in Participant, where: p.tournament_id == ^tournament_id, select: count(p.id)
      )

    cond do
      tournament.status != "registration" ->
        {:error, :registration_closed}

      tournament.max_participants && participant_count >= tournament.max_participants ->
        {:error, :tournament_full}

      true ->
        %Participant{}
        |> Participant.changeset(%{
          tournament_id: tournament_id,
          user_id: user_id,
          seed: participant_count + 1
        })
        |> Repo.insert()
    end
  end

  def start_tournament(tournament_id) do
    tournament = get_tournament!(tournament_id)
    participants = Enum.shuffle(tournament.participants)

    Repo.transaction(fn ->
      matches = generate_bracket(tournament_id, participants, 1)
      tournament |> Tournament.changeset(%{status: "in_progress"}) |> Repo.update!()
      matches
    end)
  end

  defp generate_bracket(tournament_id, participants, round) do
    pairs = Enum.chunk_every(participants, 2)

    Enum.with_index(pairs, 1)
    |> Enum.map(fn {pair, pos} ->
      attrs = %{tournament_id: tournament_id, round: round, position: pos, status: "active"}

      attrs =
        case pair do
          [p1, p2] ->
            Map.merge(attrs, %{player1_id: p1.user_id, player2_id: p2.user_id})

          [p1] ->
            Map.merge(attrs, %{player1_id: p1.user_id, winner_id: p1.user_id, status: "bye"})
        end

      %Match{} |> Match.changeset(attrs) |> Repo.insert!()
    end)
  end

  def get_current_matchup(tournament_id, user_id) do
    Repo.one(
      from m in Match,
        where:
          m.tournament_id == ^tournament_id and m.status == "active" and
            (m.player1_id == ^user_id or m.player2_id == ^user_id),
        limit: 1
    )
  end

  def submit_result(match_id, winner_id, scores) do
    match = Repo.get!(Match, match_id)

    Repo.transaction(fn ->
      match
      |> Match.changeset(%{winner_id: winner_id, scores: scores, status: "completed"})
      |> Repo.update!()

      loser_id = if match.player1_id == winner_id, do: match.player2_id, else: match.player1_id

      from(p in Participant,
        where: p.tournament_id == ^match.tournament_id and p.user_id == ^winner_id
      )
      |> Repo.update_all(inc: [wins: 1, points: 3])

      from(p in Participant,
        where: p.tournament_id == ^match.tournament_id and p.user_id == ^loser_id
      )
      |> Repo.update_all(inc: [losses: 1])

      :ok
    end)
  end

  def advance_bracket(tournament_id) do
    current_round =
      Repo.one(from m in Match, where: m.tournament_id == ^tournament_id, select: max(m.round))

    pending =
      Repo.one(
        from m in Match,
          where:
            m.tournament_id == ^tournament_id and m.round == ^current_round and
              m.status == "active",
          select: count(m.id)
      )

    if pending > 0 do
      {:error, :matches_still_active}
    else
      winners =
        Repo.all(
          from m in Match,
            where:
              m.tournament_id == ^tournament_id and m.round == ^current_round and
                not is_nil(m.winner_id),
            select: m.winner_id
        )

      if length(winners) <= 1 do
        {:ok, :tournament_complete}
      else
        winner_participants = Enum.map(winners, fn uid -> %{user_id: uid} end)
        matches = generate_bracket(tournament_id, winner_participants, current_round + 1)
        {:ok, matches}
      end
    end
  end

  def get_standings(tournament_id) do
    Participant
    |> where([p], p.tournament_id == ^tournament_id)
    |> order_by([p], desc: p.points, desc: p.wins, asc: p.losses)
    |> join(:inner, [p], u in ForgeNexus.Accounts.User, on: p.user_id == u.id)
    |> select([p, u], %{
      user_id: u.id,
      username: u.username,
      wins: p.wins,
      losses: p.losses,
      points: p.points,
      is_eliminated: p.is_eliminated
    })
    |> Repo.all()
  end

  def complete_tournament(tournament_id) do
    tournament = Repo.get!(Tournament, tournament_id)
    tournament |> Tournament.changeset(%{status: "completed"}) |> Repo.update()
  end
end
