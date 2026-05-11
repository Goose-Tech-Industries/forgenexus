defmodule ForgeNexus.Tournaments.BracketGenerator do
  @moduledoc """
  Generates tournament brackets for various formats.
  Supports single elimination, double elimination, round robin, and Swiss.
  """

  @doc "Generate a bracket from a list of seeded participant IDs."
  def generate(participant_ids, format \\ "single_elimination") do
    case format do
      "single_elimination" -> single_elimination(participant_ids)
      "double_elimination" -> double_elimination(participant_ids)
      "round_robin" -> round_robin(participant_ids)
      "swiss" -> swiss_round(participant_ids, 1, %{})
      _ -> {:error, :unknown_format}
    end
  end

  defp single_elimination(ids) do
    padded = pad_to_power_of_two(ids)
    rounds = round_count(length(padded))

    matches =
      padded
      |> Enum.chunk_every(2)
      |> Enum.with_index(1)
      |> Enum.map(fn {[p1, p2], idx} ->
        %{
          id: "r1_m#{idx}",
          round: 1,
          match_number: idx,
          player1_id: p1,
          player2_id: p2,
          winner_id: nil,
          next_match_id: next_match_id(idx, 2),
          status: if(is_nil(p2), do: "bye", else: "pending")
        }
      end)

    future_matches = generate_future_rounds(matches, 2, rounds)
    all_matches = matches ++ future_matches

    {:ok, %{
      format: "single_elimination",
      rounds: rounds,
      participant_count: length(ids),
      matches: all_matches
    }}
  end

  defp double_elimination(ids) do
    {:ok, winners} = single_elimination(ids)

    losers_rounds = winners.rounds
    losers_matches =
      Enum.map(1..losers_rounds, fn round ->
        match_count = max(div(length(ids), trunc(:math.pow(2, round))), 1)
        Enum.map(1..match_count, fn idx ->
          %{
            id: "L_r#{round}_m#{idx}",
            round: round,
            match_number: idx,
            bracket: "losers",
            player1_id: nil,
            player2_id: nil,
            winner_id: nil,
            status: "pending"
          }
        end)
      end)
      |> List.flatten()

    grand_final = %{
      id: "grand_final",
      round: winners.rounds + 1,
      match_number: 1,
      bracket: "grand_final",
      player1_id: nil,
      player2_id: nil,
      winner_id: nil,
      status: "pending"
    }

    {:ok, %{
      format: "double_elimination",
      rounds: winners.rounds + losers_rounds + 1,
      participant_count: length(ids),
      winners_bracket: winners.matches,
      losers_bracket: losers_matches,
      grand_final: grand_final
    }}
  end

  defp round_robin(ids) do
    n = length(ids)
    padded = if rem(n, 2) == 1, do: ids ++ [nil], else: ids
    total = length(padded)
    rounds = total - 1

    matches =
      Enum.flat_map(1..rounds, fn round ->
        rotated = rotate(padded, round - 1)
        first_half = Enum.take(rotated, div(total, 2))
        second_half = rotated |> Enum.drop(div(total, 2)) |> Enum.reverse()

        Enum.zip(first_half, second_half)
        |> Enum.with_index(1)
        |> Enum.reject(fn {{p1, p2}, _} -> is_nil(p1) or is_nil(p2) end)
        |> Enum.map(fn {{p1, p2}, idx} ->
          %{
            id: "rr_r#{round}_m#{idx}",
            round: round,
            match_number: idx,
            player1_id: p1,
            player2_id: p2,
            winner_id: nil,
            status: "pending"
          }
        end)
      end)

    {:ok, %{format: "round_robin", rounds: rounds, participant_count: n, matches: matches}}
  end

  defp swiss_round(ids, round_number, standings) do
    sorted =
      if map_size(standings) == 0 do
        Enum.shuffle(ids)
      else
        Enum.sort_by(ids, fn id -> -(Map.get(standings, id, 0)) end)
      end

    matches =
      sorted
      |> Enum.chunk_every(2)
      |> Enum.with_index(1)
      |> Enum.map(fn {pair, idx} ->
        [p1 | rest] = pair
        p2 = List.first(rest)
        %{
          id: "sw_r#{round_number}_m#{idx}",
          round: round_number,
          match_number: idx,
          player1_id: p1,
          player2_id: p2,
          winner_id: nil,
          status: if(is_nil(p2), do: "bye", else: "pending")
        }
      end)

    {:ok, %{format: "swiss", round: round_number, matches: matches, standings: standings}}
  end

  defp pad_to_power_of_two(ids) do
    n = length(ids)
    target = :math.pow(2, :math.ceil(:math.log2(max(n, 2)))) |> trunc()
    ids ++ List.duplicate(nil, target - n)
  end

  defp round_count(n), do: :math.log2(n) |> trunc()

  defp next_match_id(match_num, next_round) do
    "r#{next_round}_m#{div(match_num + 1, 2)}"
  end

  defp generate_future_rounds(_, current, total) when current > total, do: []

  defp generate_future_rounds(prev_matches, current, total) do
    prev_count = Enum.count(prev_matches, fn m -> m.round == current - 1 end)
    match_count = max(div(prev_count, 2), 1)

    matches =
      Enum.map(1..match_count, fn idx ->
        %{
          id: "r#{current}_m#{idx}",
          round: current,
          match_number: idx,
          player1_id: nil,
          player2_id: nil,
          winner_id: nil,
          next_match_id: if(current < total, do: next_match_id(idx, current + 1), else: nil),
          status: "pending"
        }
      end)

    matches ++ generate_future_rounds(prev_matches ++ matches, current + 1, total)
  end

  defp rotate([first | rest], 0), do: [first | rest]
  defp rotate([first | rest], n), do: rotate(rest ++ [first], n - 1)
end
