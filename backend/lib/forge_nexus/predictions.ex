defmodule ForgeNexus.Predictions do
  @moduledoc "Prediction markets, suggestion voting, and bet resolution."
  import Ecto.Query
  alias ForgeNexus.Repo

  alias ForgeNexus.Predictions.{
    Prediction,
    PredictionOption,
    PredictionBet,
    Suggestion,
    SuggestionVote
  }

  # Predictions

  def create_prediction(attrs), do: %Prediction{} |> Prediction.changeset(attrs) |> Repo.insert()

  def get_prediction!(id), do: Repo.get!(Prediction, id) |> Repo.preload([:options, :bets])

  def list_predictions(status \\ nil) do
    query = Prediction |> order_by(desc: :inserted_at) |> preload(:options)

    if status,
      do: where(query, [p], p.status == ^status),
      else:
        query
        |> Repo.all()
  end

  def place_bet(user_id, option_id, amount) do
    option = Repo.get!(PredictionOption, option_id)
    prediction = Repo.get!(Prediction, option.prediction_id)

    if prediction.status != "open" do
      {:error, :prediction_not_open}
    else
      Repo.transaction(fn ->
        case ForgeNexus.Economy.deduct_points(user_id, amount, "prediction_bet") do
          {:ok, _} ->
            bet =
              %PredictionBet{}
              |> PredictionBet.changeset(%{
                user_id: user_id,
                prediction_id: prediction.id,
                option_id: option_id,
                amount: amount
              })
              |> Repo.insert!()

            from(o in PredictionOption, where: o.id == ^option_id)
            |> Repo.update_all(inc: [total_amount: amount])

            bet

          {:error, reason} ->
            Repo.rollback(reason)
        end
      end)
    end
  end

  def resolve_prediction(prediction_id, winning_option_label) do
    prediction = get_prediction!(prediction_id)
    winning_option = Enum.find(prediction.options, fn o -> o.label == winning_option_label end)
    if is_nil(winning_option), do: {:error, :invalid_option}

    total_pool = Enum.reduce(prediction.options, 0, fn o, acc -> acc + o.total_amount end)
    winning_pool = winning_option.total_amount

    Repo.transaction(fn ->
      if winning_pool > 0 do
        winning_bets =
          Repo.all(
            from b in PredictionBet,
              where: b.prediction_id == ^prediction_id and b.option_id == ^winning_option.id
          )

        Enum.each(winning_bets, fn bet ->
          payout = trunc(bet.amount / winning_pool * total_pool)

          if payout > 0 do
            ForgeNexus.Economy.award_points(bet.user_id, "prediction_payout", amount: payout)
          end
        end)
      end

      now = DateTime.utc_now() |> DateTime.truncate(:second)

      prediction
      |> Prediction.changeset(%{
        status: "resolved",
        winning_option: winning_option_label,
        resolved_at: now
      })
      |> Repo.update!()
    end)
  end

  def cancel_prediction(prediction_id) do
    prediction = get_prediction!(prediction_id)

    Repo.transaction(fn ->
      bets = Repo.all(from b in PredictionBet, where: b.prediction_id == ^prediction_id)

      Enum.each(bets, fn bet ->
        ForgeNexus.Economy.award_points(bet.user_id, "prediction_refund", amount: bet.amount)
      end)

      prediction |> Prediction.changeset(%{status: "cancelled"}) |> Repo.update!()
    end)
  end

  # Suggestions

  def create_suggestion(attrs), do: %Suggestion{} |> Suggestion.changeset(attrs) |> Repo.insert()

  def vote_suggestion(suggestion_id, user_id, direction) when direction in [:up, :down] do
    dir_str = Atom.to_string(direction)

    case Repo.one(
           from v in SuggestionVote,
             where: v.suggestion_id == ^suggestion_id and v.user_id == ^user_id
         ) do
      nil ->
        Repo.transaction(fn ->
          %SuggestionVote{}
          |> SuggestionVote.changeset(%{
            suggestion_id: suggestion_id,
            user_id: user_id,
            direction: dir_str
          })
          |> Repo.insert!()

          inc_field = if direction == :up, do: [upvotes: 1], else: [downvotes: 1]
          from(s in Suggestion, where: s.id == ^suggestion_id) |> Repo.update_all(inc: inc_field)
          :ok
        end)

      existing ->
        if existing.direction == dir_str do
          {:error, :already_voted}
        else
          Repo.transaction(fn ->
            existing |> SuggestionVote.changeset(%{direction: dir_str}) |> Repo.update!()

            {inc_field, dec_field} =
              if direction == :up,
                do: {[upvotes: 1], [downvotes: -1]},
                else: {[downvotes: 1], [upvotes: -1]}

            from(s in Suggestion, where: s.id == ^suggestion_id)
            |> Repo.update_all(inc: inc_field ++ dec_field)

            :ok
          end)
        end
    end
  end

  def update_suggestion_status(suggestion_id, status) do
    suggestion = Repo.get!(Suggestion, suggestion_id)
    suggestion |> Suggestion.changeset(%{status: status}) |> Repo.update()
  end
end
