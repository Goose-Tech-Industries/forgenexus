defmodule ForgeNexus.Events.EventsSchemasTest do
  use ForgeNexus.DataCase, async: true

  alias ForgeNexus.Events.{Event, EventRsvp, EventTicket}

  describe "Event" do
    @uid Ecto.UUID.generate()

    test "valid changeset and event_type inclusions" do
      start_time = ~U[2026-06-01 18:00:00Z]

      for etype <- ~w(community contest tournament stream meetup custom) do
        cs =
          Event.changeset(%Event{}, %{
            title: "Community Meetup",
            starts_at: start_time,
            created_by_id: @uid,
            event_type: etype
          })

        assert cs.valid?
        assert get_field(cs, :event_type) == etype
      end

      req_cs = Event.changeset(%Event{}, %{})
      refute req_cs.valid?
      assert "can't be blank" in errors_on(req_cs).title
      assert "can't be blank" in errors_on(req_cs).starts_at
      assert "can't be blank" in errors_on(req_cs).created_by_id

      bad_type_cs =
        Event.changeset(%Event{}, %{
          title: "Test",
          starts_at: start_time,
          created_by_id: @uid,
          event_type: "secret_gathering"
        })

      refute bad_type_cs.valid?
      assert "is invalid" in errors_on(bad_type_cs).event_type
    end
  end

  describe "EventRsvp" do
    @eid Ecto.UUID.generate()
    @uid Ecto.UUID.generate()

    test "valid changeset and status inclusions" do
      for status <- ~w(going maybe not_going) do
        cs =
          EventRsvp.changeset(%EventRsvp{}, %{
            event_id: @eid,
            user_id: @uid,
            status: status
          })

        assert cs.valid?
        assert get_field(cs, :status) == status
      end

      req_cs = EventRsvp.changeset(%EventRsvp{}, %{})
      refute req_cs.valid?
      assert "can't be blank" in errors_on(req_cs).event_id
      assert "can't be blank" in errors_on(req_cs).user_id

      bad_status_cs =
        EventRsvp.changeset(%EventRsvp{}, %{
          event_id: @eid,
          user_id: @uid,
          status: "undecided"
        })

      refute bad_status_cs.valid?
      assert "is invalid" in errors_on(bad_status_cs).status
    end
  end

  describe "EventTicket" do
    @eid Ecto.UUID.generate()
    @uid Ecto.UUID.generate()

    test "valid changeset and inclusions" do
      for status <- ~w(valid used cancelled refunded) do
        for ptype <- ~w(free points money) do
          cs =
            EventTicket.changeset(%EventTicket{}, %{
              event_id: @eid,
              user_id: @uid,
              status: status,
              payment_type: ptype
            })

          assert cs.valid?
          assert get_field(cs, :status) == status
          assert get_field(cs, :payment_type) == ptype
        end
      end

      req_cs = EventTicket.changeset(%EventTicket{}, %{})
      refute req_cs.valid?
      assert "can't be blank" in errors_on(req_cs).event_id
      assert "can't be blank" in errors_on(req_cs).user_id

      bad_cs =
        EventTicket.changeset(%EventTicket{}, %{
          event_id: @eid,
          user_id: @uid,
          status: "lost",
          payment_type: "crypto"
        })

      refute bad_cs.valid?
      assert "is invalid" in errors_on(bad_cs).status
      assert "is invalid" in errors_on(bad_cs).payment_type
    end
  end
end
