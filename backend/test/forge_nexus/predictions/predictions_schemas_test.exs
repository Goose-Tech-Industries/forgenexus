defmodule ForgeNexus.Predictions.PredictionsSchemasTest do
  use ForgeNexus.DataCase, async: true

  alias ForgeNexus.Predictions.{
    Prediction,
    PredictionBet,
    PredictionOption,
    Suggestion,
    SuggestionVote
  }

  describe "Prediction" do
    @uid Ecto.UUID.generate()

    test "valid changeset and status inclusions" do
      for status <- ~w(open locked resolved cancelled) do
        cs =
          Prediction.changeset(%Prediction{}, %{
            title: "Will Elixir 2.0 release in 2026?",
            created_by_id: @uid,
            status: status
          })

        assert cs.valid?
        assert get_field(cs, :status) == status
      end

      req_cs = Prediction.changeset(%Prediction{}, %{})
      refute req_cs.valid?
      assert "can't be blank" in errors_on(req_cs).title
      assert "can't be blank" in errors_on(req_cs).created_by_id

      bad_status_cs =
        Prediction.changeset(%Prediction{}, %{
          title: "Test",
          created_by_id: @uid,
          status: "void"
        })

      refute bad_status_cs.valid?
      assert "is invalid" in errors_on(bad_status_cs).status
    end
  end

  describe "PredictionBet" do
    @uid Ecto.UUID.generate()
    @pid Ecto.UUID.generate()
    @oid Ecto.UUID.generate()

    test "valid changeset and validations" do
      cs =
        PredictionBet.changeset(%PredictionBet{}, %{
          amount: 100,
          user_id: @uid,
          prediction_id: @pid,
          option_id: @oid
        })

      assert cs.valid?
      assert get_field(cs, :amount) == 100

      req_cs = PredictionBet.changeset(%PredictionBet{}, %{})
      refute req_cs.valid?
      assert "can't be blank" in errors_on(req_cs).amount
      assert "can't be blank" in errors_on(req_cs).user_id
      assert "can't be blank" in errors_on(req_cs).prediction_id
      assert "can't be blank" in errors_on(req_cs).option_id

      zero_cs =
        PredictionBet.changeset(%PredictionBet{}, %{
          amount: 0,
          user_id: @uid,
          prediction_id: @pid,
          option_id: @oid
        })

      refute zero_cs.valid?
      assert "must be greater than 0" in errors_on(zero_cs).amount
    end
  end

  describe "PredictionOption" do
    @pid Ecto.UUID.generate()

    test "valid changeset" do
      cs =
        PredictionOption.changeset(%PredictionOption{}, %{
          label: "Yes",
          prediction_id: @pid,
          total_amount: 500
        })

      assert cs.valid?
      assert get_field(cs, :label) == "Yes"

      req_cs = PredictionOption.changeset(%PredictionOption{}, %{})
      refute req_cs.valid?
      assert "can't be blank" in errors_on(req_cs).label
      assert "can't be blank" in errors_on(req_cs).prediction_id
    end
  end

  describe "Suggestion" do
    @uid Ecto.UUID.generate()

    test "valid changeset and status inclusions" do
      for status <- ~w(pending under_review accepted rejected completed) do
        cs =
          Suggestion.changeset(%Suggestion{}, %{
            title: "Dark mode support",
            description: "Please add high-contrast dark mode",
            user_id: @uid,
            status: status
          })

        assert cs.valid?
        assert get_field(cs, :status) == status
      end

      req_cs = Suggestion.changeset(%Suggestion{}, %{})
      refute req_cs.valid?
      assert "can't be blank" in errors_on(req_cs).title
      assert "can't be blank" in errors_on(req_cs).description
      assert "can't be blank" in errors_on(req_cs).user_id

      bad_status_cs =
        Suggestion.changeset(%Suggestion{}, %{
          title: "Test",
          description: "Desc",
          user_id: @uid,
          status: "tabled"
        })

      refute bad_status_cs.valid?
      assert "is invalid" in errors_on(bad_status_cs).status
    end
  end

  describe "SuggestionVote" do
    @uid Ecto.UUID.generate()
    @sid Ecto.UUID.generate()

    test "valid changeset and direction inclusions" do
      for dir <- ~w(up down) do
        cs =
          SuggestionVote.changeset(%SuggestionVote{}, %{
            direction: dir,
            suggestion_id: @sid,
            user_id: @uid
          })

        assert cs.valid?
        assert get_field(cs, :direction) == dir
      end

      req_cs = SuggestionVote.changeset(%SuggestionVote{}, %{})
      refute req_cs.valid?
      assert "can't be blank" in errors_on(req_cs).direction
      assert "can't be blank" in errors_on(req_cs).suggestion_id
      assert "can't be blank" in errors_on(req_cs).user_id

      bad_dir_cs =
        SuggestionVote.changeset(%SuggestionVote{}, %{
          direction: "sideways",
          suggestion_id: @sid,
          user_id: @uid
        })

      refute bad_dir_cs.valid?
      assert "is invalid" in errors_on(bad_dir_cs).direction
    end
  end
end
