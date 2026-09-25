defmodule ForgeNexus.Tickets.TicketSchemasTest do
  use ForgeNexus.DataCase, async: true

  alias ForgeNexus.Tickets.{Ticket, TicketMessage}

  describe "Ticket" do
    @uid Ecto.UUID.generate()

    test "valid changeset and inclusions" do
      for status <- ~w(open in_progress waiting_on_user resolved closed escalated) do
        for prio <- ~w(low normal high urgent) do
          cs =
            Ticket.changeset(%Ticket{}, %{
              title: "Help needed",
              description: "Cannot access settings",
              user_id: @uid,
              status: status,
              priority: prio,
              rating: 5
            })

          assert cs.valid?
          assert get_field(cs, :status) == status
          assert get_field(cs, :priority) == prio
        end
      end

      # Required fields
      req_cs = Ticket.changeset(%Ticket{}, %{})
      refute req_cs.valid?
      assert "can't be blank" in errors_on(req_cs).title
      assert "can't be blank" in errors_on(req_cs).description
      assert "can't be blank" in errors_on(req_cs).user_id

      # Invalid inclusions and rating bounds
      bad_cs =
        Ticket.changeset(%Ticket{}, %{
          title: "Test",
          description: "Desc",
          user_id: @uid,
          status: "abandoned",
          priority: "super_urgent",
          rating: 6
        })

      refute bad_cs.valid?
      assert "is invalid" in errors_on(bad_cs).status
      assert "is invalid" in errors_on(bad_cs).priority
      assert "must be less than or equal to 5" in errors_on(bad_cs).rating

      low_rating_cs =
        Ticket.changeset(%Ticket{}, %{
          title: "Test",
          description: "Desc",
          user_id: @uid,
          rating: 0
        })

      refute low_rating_cs.valid?
      assert "must be greater than or equal to 1" in errors_on(low_rating_cs).rating
    end
  end

  describe "TicketMessage" do
    @tid Ecto.UUID.generate()
    @uid Ecto.UUID.generate()

    test "valid changeset" do
      cs =
        TicketMessage.changeset(%TicketMessage{}, %{
          body: "Have you tried turning it off and on again?",
          ticket_id: @tid,
          user_id: @uid,
          is_internal: true
        })

      assert cs.valid?
      assert get_field(cs, :is_internal) == true

      req_cs = TicketMessage.changeset(%TicketMessage{}, %{})
      refute req_cs.valid?
      assert "can't be blank" in errors_on(req_cs).body
      assert "can't be blank" in errors_on(req_cs).ticket_id
      assert "can't be blank" in errors_on(req_cs).user_id
    end
  end
end
