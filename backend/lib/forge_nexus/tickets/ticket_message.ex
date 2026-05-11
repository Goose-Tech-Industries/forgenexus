defmodule ForgeNexus.Tickets.TicketMessage do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "ticket_messages" do
    field :body, :string
    field :is_internal, :boolean, default: false

    belongs_to :ticket, ForgeNexus.Tickets.Ticket
    belongs_to :user, ForgeNexus.Accounts.User

    timestamps()
  end

  def changeset(message, attrs) do
    message
    |> cast(attrs, [:body, :is_internal, :ticket_id, :user_id])
    |> validate_required([:body, :ticket_id, :user_id])
  end
end
