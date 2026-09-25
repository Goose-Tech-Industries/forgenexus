defmodule ForgeNexus.Games.PartyGameSchemaTest do
  use ForgeNexus.DataCase, async: true

  alias ForgeNexus.Games.PartyGame

  describe "PartyGame" do
    test "valid changeset, game_types/0, and inclusions" do
      types = PartyGame.game_types()
      assert "trivia" in types
      assert "mafia" in types

      for gtype <- types do
        for status <- ~w(lobby playing round_end game_over cancelled) do
          cs =
            PartyGame.changeset(%PartyGame{}, %{
              game_type: gtype,
              status: status,
              max_players: 8
            })

          assert cs.valid?
          assert get_field(cs, :game_type) == gtype
          assert get_field(cs, :status) == status
        end
      end

      req_cs = PartyGame.changeset(%PartyGame{}, %{})
      refute req_cs.valid?
      assert "can't be blank" in errors_on(req_cs).game_type

      bad_cs =
        PartyGame.changeset(%PartyGame{}, %{
          game_type: "chess",
          status: "paused",
          max_players: 1
        })

      refute bad_cs.valid?
      assert "is invalid" in errors_on(bad_cs).game_type
      assert "is invalid" in errors_on(bad_cs).status
      assert "must be greater than 1" in errors_on(bad_cs).max_players

      over_players_cs =
        PartyGame.changeset(%PartyGame{}, %{
          game_type: "trivia",
          max_players: 51
        })

      refute over_players_cs.valid?
      assert "must be less than or equal to 50" in errors_on(over_players_cs).max_players
    end
  end
end
