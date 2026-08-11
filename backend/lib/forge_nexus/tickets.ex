defmodule ForgeNexus.Tickets do
  @moduledoc "Support ticket system with messages, assignment, and ratings."
  import Ecto.Query
  alias ForgeNexus.Repo
  alias ForgeNexus.Tickets.{Ticket, TicketMessage}

  def create_ticket(attrs) do
    %Ticket{} |> Ticket.changeset(attrs) |> Repo.insert()
  end

  def get_ticket!(id) do
    Repo.get!(Ticket, id) |> Repo.preload([:user, :assigned_to, messages: [:user]])
  end

  def list_tickets(opts \\ []) do
    query = Ticket |> order_by(desc: :inserted_at)

    query =
      case Keyword.get(opts, :status) do
        nil -> query
        status -> where(query, [t], t.status == ^status)
      end

    query =
      case Keyword.get(opts, :assigned_to) do
        nil -> query
        staff_id -> where(query, [t], t.assigned_to_id == ^staff_id)
      end

    query =
      case Keyword.get(opts, :user_id) do
        nil -> query
        uid -> where(query, [t], t.user_id == ^uid)
      end

    query |> preload([:user, :assigned_to]) |> Repo.all()
  end

  def update_status(ticket_id, new_status) do
    ticket = Repo.get!(Ticket, ticket_id)
    ticket |> Ticket.changeset(%{status: new_status}) |> Repo.update()
  end

  def assign_ticket(ticket_id, staff_user_id) do
    ticket = Repo.get!(Ticket, ticket_id)
    ticket |> Ticket.changeset(%{assigned_to_id: staff_user_id}) |> Repo.update()
  end

  def claim_ticket(ticket_id, staff_user_id) do
    ticket = Repo.get!(Ticket, ticket_id)

    ticket
    |> Ticket.changeset(%{assigned_to_id: staff_user_id, status: "in_progress"})
    |> Repo.update()
  end

  def add_message(attrs) do
    %TicketMessage{} |> TicketMessage.changeset(attrs) |> Repo.insert()
  end

  def close_with_rating(ticket_id, rating) do
    ticket = Repo.get!(Ticket, ticket_id)
    ticket |> Ticket.changeset(%{status: "closed", rating: rating}) |> Repo.update()
  end

  def escalate_ticket(ticket_id, reason) do
    ticket = Repo.get!(Ticket, ticket_id)
    ticket |> Ticket.changeset(%{status: "escalated", escalation_reason: reason}) |> Repo.update()
  end

  def get_ticket(id) do
    case Repo.get(Ticket, id) do
      nil -> {:error, :not_found}
      ticket -> {:ok, ticket}
    end
  end
end
