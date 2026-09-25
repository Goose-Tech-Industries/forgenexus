defmodule ForgeNexus.Tournaments.TournamentSchemasTest do
  use ForgeNexus.DataCase, async: true

  alias ForgeNexus.Tournaments.{
    Tournament,
    Match,
    Participant
  }

  describe "Tournament" do
    test "valid changeset and inclusions" do
      for fmt <- ~w(single_elimination double_elimination round_robin swiss) do
        for status <- ~w(registration active in_progress completed cancelled) do
          cs =
            Tournament.changeset(%Tournament{}, %{
              name: "Summer Championship",
              format: fmt,
              status: status
            })

          assert cs.valid?
          assert get_field(cs, :format) == fmt
          assert get_field(cs, :status) == status
        end
      end

      # Required fields
      req_cs = Tournament.changeset(%Tournament{}, %{format: nil})
      refute req_cs.valid?
      assert "can't be blank" in errors_on(req_cs).name
      assert "can't be blank" in errors_on(req_cs).format

      # Invalid inclusions
      bad_cs =
        Tournament.changeset(%Tournament{}, %{
          name: "Test",
          format: "battle_royale",
          status: "destroyed"
        })

      refute bad_cs.valid?
      assert "is invalid" in errors_on(bad_cs).format
      assert "is invalid" in errors_on(bad_cs).status
    end
  end

  describe "Match" do
    @tid Ecto.UUID.generate()

    test "valid changeset and status inclusions" do
      for status <- ~w(pending active completed bye) do
        cs =
          Match.changeset(%Match{}, %{
            tournament_id: @tid,
            round: 1,
            position: 2,
            status: status
          })

        assert cs.valid?
        assert get_field(cs, :status) == status
      end

      # Required fields
      req_cs = Match.changeset(%Match{}, %{})
      refute req_cs.valid?
      assert "can't be blank" in errors_on(req_cs).tournament_id
      assert "can't be blank" in errors_on(req_cs).round
      assert "can't be blank" in errors_on(req_cs).position

      # Invalid status
      bad_cs =
        Match.changeset(%Match{}, %{
          tournament_id: @tid,
          round: 1,
          position: 2,
          status: "abandoned"
        })

      refute bad_cs.valid?
      assert "is invalid" in errors_on(bad_cs).status
    end
  end

  describe "Participant" do
    @tid Ecto.UUID.generate()
    @uid Ecto.UUID.generate()

    test "valid changeset" do
      cs =
        Participant.changeset(%Participant{}, %{
          tournament_id: @tid,
          user_id: @uid,
          seed: 1,
          wins: 3,
          losses: 0
        })

      assert cs.valid?
      assert get_field(cs, :seed) == 1
      assert get_field(cs, :wins) == 3

      req_cs = Participant.changeset(%Participant{}, %{})
      refute req_cs.valid?
      assert "can't be blank" in errors_on(req_cs).tournament_id
      assert "can't be blank" in errors_on(req_cs).user_id
    end
  end
end
