defmodule ForgeNexus.Tournaments.Registration do
  @moduledoc """
  Handles tournament registration with optional point-based entry fees.
  Deducts points on registration, refunds on cancellation, distributes
  prize pool to winners based on placement.
  """

  import Ecto.Query
  alias ForgeNexus.{Repo, Economy}

  def register(tournament_id, user_id) do
    tournament = Repo.get!(ForgeNexus.Tournaments.Tournament, tournament_id)
    already = Repo.exists?(from p in "tournament_participants",
      where: p.tournament_id == ^tournament_id and p.user_id == ^user_id)

    cond do
      already ->
        {:error, :already_registered}

      tournament.status != "upcoming" ->
        {:error, :registration_closed}

      tournament.entry_fee_points > 0 ->
        balance = Economy.get_points(user_id)

        if balance < tournament.entry_fee_points do
          {:error, :insufficient_points}
        else
          Economy.deduct_points(user_id, tournament.entry_fee_points, "tournament_entry",
            description: "Entry fee for #{tournament.name || "tournament"}")

          insert_participant(tournament_id, user_id)
          update_prize_pool(tournament_id, tournament.entry_fee_points)
          {:ok, :registered}
        end

      true ->
        insert_participant(tournament_id, user_id)
        {:ok, :registered}
    end
  end

  def unregister(tournament_id, user_id) do
    tournament = Repo.get!(ForgeNexus.Tournaments.Tournament, tournament_id)

    if tournament.status != "upcoming" do
      {:error, :cannot_unregister}
    else
      {count, _} = from(p in "tournament_participants",
        where: p.tournament_id == ^tournament_id and p.user_id == ^user_id
      ) |> Repo.delete_all()

      if count > 0 and tournament.entry_fee_points > 0 do
        Economy.award_points(user_id, "tournament_refund",
          amount: tournament.entry_fee_points,
          description: "Refund for #{tournament.name || "tournament"}")
      end

      {:ok, :unregistered}
    end
  end

  def distribute_prizes(tournament_id, placements) do
    tournament = Repo.get!(ForgeNexus.Tournaments.Tournament, tournament_id)
    total_pool = tournament.prize_pool_points || 0

    if total_pool > 0 do
      distribution = calculate_distribution(total_pool, length(placements))

      Enum.zip(placements, distribution)
      |> Enum.each(fn {user_id, amount} ->
        if amount > 0 do
          Economy.award_points(user_id, "tournament_prize",
            amount: amount,
            description: "Tournament prize — #{tournament.name}")

          from(p in "tournament_participants",
            where: p.tournament_id == ^tournament_id and p.user_id == ^user_id
          ) |> Repo.update_all(set: [prize_points: amount])
        end
      end)

      {:ok, distribution}
    else
      {:ok, []}
    end
  end

  defp calculate_distribution(total, placement_count) do
    case min(placement_count, 3) do
      1 -> [total]
      2 -> [round(total * 0.70), round(total * 0.30)]
      _ -> [round(total * 0.50), round(total * 0.30), round(total * 0.20)]
    end
  end

  defp insert_participant(tournament_id, user_id) do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

    Repo.insert_all("tournament_participants", [
      %{
        id: Ecto.UUID.generate(),
        tournament_id: tournament_id,
        user_id: user_id,
        checked_in: false,
        inserted_at: now,
        updated_at: now
      }
    ], on_conflict: :nothing)
  end

  defp update_prize_pool(tournament_id, points) do
    from(t in "tournaments", where: t.id == ^tournament_id)
    |> Repo.update_all(inc: [prize_pool_points: points])
  end
end
