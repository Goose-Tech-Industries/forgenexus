defmodule ForgeNexus.Tickets.Ticket do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "tickets" do
    field :title, :string
    field :description, :string
    field :status, :string, default: "open"
    field :priority, :string, default: "normal"
    field :category, :string
    field :rating, :integer
    field :escalation_reason, :string

    belongs_to :user, ForgeNexus.Accounts.User
    belongs_to :assigned_to, ForgeNexus.Accounts.User
    has_many :messages, ForgeNexus.Tickets.TicketMessage

    timestamps()
  end

  def changeset(ticket, attrs) do
    ticket
    |> cast(attrs, [:title, :description, :status, :priority, :category, :rating, :escalation_reason, :user_id, :assigned_to_id])
    |> validate_required([:title, :description, :user_id])
    |> validate_inclusion(:status, ~w(open in_progress waiting_on_user resolved closed escalated))
    |> validate_inclusion(:priority, ~w(low normal high urgent))
    |> validate_number(:rating, greater_than_or_equal_to: 1, less_than_or_equal_to: 5)
  end
end
