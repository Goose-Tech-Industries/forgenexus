defmodule ForgeNexus.Voice.CallLogTest do
  use ForgeNexus.DataCase, async: true

  alias ForgeNexus.Voice.CallLog

  describe "CallLog schema & changesets" do
    @rid Ecto.UUID.generate()
    @uid Ecto.UUID.generate()
    @valid_attrs %{
      room_id: @rid,
      room_type: "public",
      started_at: ~U[2026-03-01 12:00:00Z],
      ended_at: ~U[2026-03-01 13:00:00Z],
      participant_ids: [@uid],
      peak_participants: 12,
      peak_audience: 10,
      peak_speakers: 2,
      total_hand_raises: 5,
      total_promotions: 2,
      total_demotions: 1,
      host_user_id: @uid
    }

    test "valid changeset with all attributes" do
      cs = CallLog.changeset(%CallLog{}, @valid_attrs)
      assert cs.valid?
      assert get_field(cs, :room_id) == @rid
      assert get_field(cs, :room_type) == "public"
      assert get_field(cs, :started_at) == ~U[2026-03-01 12:00:00Z]
      assert get_field(cs, :peak_participants) == 12
      assert get_field(cs, :host_user_id) == @uid
    end

    test "requires started_at" do
      cs = CallLog.changeset(%CallLog{}, %{})
      refute cs.valid?
      assert "can't be blank" in errors_on(cs).started_at
    end
  end
end
