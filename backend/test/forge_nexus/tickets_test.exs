defmodule ForgeNexus.TicketsTest do
  use ForgeNexus.DataCase, async: true

  alias ForgeNexus.Tickets
  alias ForgeNexus.Tickets.{Ticket, TicketMessage}
  alias ForgeNexus.Accounts

  defp create_user do
    unique = System.unique_integer([:positive])

    {:ok, user} =
      Accounts.register_user(%{
        username: "tkt_u_#{unique}",
        email: "tkt_u_#{unique}@example.com",
        password: "ValidPassword123!@#"
      })

    user
  end

  defp ticket_attrs(user_id, attrs \\ %{}) do
    Enum.into(attrs, %{
      title: "Cannot access account",
      description: "Getting error 500 when accessing billing page",
      user_id: user_id,
      category: "billing",
      priority: "high",
      status: "open"
    })
  end

  describe "create_ticket/1 and get_ticket/1" do
    test "creates ticket with valid attrs and preloads associations" do
      user = create_user()
      attrs = ticket_attrs(user.id)

      assert {:ok, %Ticket{} = ticket} = Tickets.create_ticket(attrs)
      assert ticket.title == attrs.title
      assert ticket.status == "open"

      assert {:ok, fetched} = Tickets.get_ticket(ticket.id)
      assert fetched.id == ticket.id

      assert {:error, :not_found} = Tickets.get_ticket(Ecto.UUID.generate())

      assert %Ticket{} = fetched_bang = Tickets.get_ticket!(ticket.id)
      assert fetched_bang.user.id == user.id
    end

    test "create_ticket/1 fails with invalid attributes" do
      assert {:error, changeset} = Tickets.create_ticket(%{title: nil})
      assert "can't be blank" in errors_on(changeset).title
      assert "can't be blank" in errors_on(changeset).description
      assert "can't be blank" in errors_on(changeset).user_id
    end
  end

  describe "list_tickets/1 filtering" do
    test "lists tickets filtered by status, assigned_to, and user_id" do
      user1 = create_user()
      user2 = create_user()
      staff = create_user()

      {:ok, t1} = Tickets.create_ticket(ticket_attrs(user1.id, %{status: "open"}))
      {:ok, t2} = Tickets.create_ticket(ticket_attrs(user1.id, %{status: "closed"}))

      {:ok, t3} =
        Tickets.create_ticket(ticket_attrs(user2.id, %{status: "open", assigned_to_id: staff.id}))

      # All tickets
      all = Tickets.list_tickets()
      all_ids = Enum.map(all, & &1.id)
      assert t1.id in all_ids
      assert t2.id in all_ids
      assert t3.id in all_ids

      # Filter by status
      open_tickets = Tickets.list_tickets(status: "open")
      open_ids = Enum.map(open_tickets, & &1.id)
      assert t1.id in open_ids
      assert t3.id in open_ids
      refute t2.id in open_ids

      # Filter by assigned_to
      assigned = Tickets.list_tickets(assigned_to: staff.id)
      assert Enum.map(assigned, & &1.id) == [t3.id]

      # Filter by user_id
      user1_tickets = Tickets.list_tickets(user_id: user1.id)
      u1_ids = Enum.map(user1_tickets, & &1.id)
      assert t1.id in u1_ids
      assert t2.id in u1_ids
      refute t3.id in u1_ids
    end
  end

  describe "ticket workflows: update_status, assign, claim, close, escalate, add_message" do
    test "assign_ticket/2 and claim_ticket/2" do
      user = create_user()
      staff = create_user()
      {:ok, ticket} = Tickets.create_ticket(ticket_attrs(user.id))

      assert {:ok, assigned} = Tickets.assign_ticket(ticket.id, staff.id)
      assert assigned.assigned_to_id == staff.id

      assert {:ok, claimed} = Tickets.claim_ticket(ticket.id, staff.id)
      assert claimed.assigned_to_id == staff.id
      assert claimed.status == "in_progress"
    end

    test "update_status/2, close_with_rating/2, escalate_ticket/2" do
      user = create_user()
      {:ok, ticket} = Tickets.create_ticket(ticket_attrs(user.id))

      assert {:ok, updated} = Tickets.update_status(ticket.id, "waiting_on_user")
      assert updated.status == "waiting_on_user"

      assert {:ok, escalated} = Tickets.escalate_ticket(ticket.id, "Requires level 2 manager")
      assert escalated.status == "escalated"
      assert escalated.escalation_reason == "Requires level 2 manager"

      assert {:ok, closed} = Tickets.close_with_rating(ticket.id, 5)
      assert closed.status == "closed"
      assert closed.rating == 5
    end

    test "add_message/1 adds internal and external messages" do
      user = create_user()
      staff = create_user()
      {:ok, ticket} = Tickets.create_ticket(ticket_attrs(user.id))

      assert {:ok, %TicketMessage{} = msg1} =
               Tickets.add_message(%{
                 ticket_id: ticket.id,
                 user_id: user.id,
                 body: "Please help, here is a screenshot",
                 is_internal: false
               })

      assert msg1.body == "Please help, here is a screenshot"
      refute msg1.is_internal

      assert {:ok, %TicketMessage{} = msg2} =
               Tickets.add_message(%{
                 ticket_id: ticket.id,
                 user_id: staff.id,
                 body: "Checked database logs, account locked",
                 is_internal: true
               })

      assert msg2.is_internal == true

      # Messages preloaded in get_ticket!
      reloaded = Tickets.get_ticket!(ticket.id)
      assert length(reloaded.messages) == 2
    end
  end
end
