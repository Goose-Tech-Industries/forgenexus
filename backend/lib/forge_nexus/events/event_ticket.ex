defmodule ForgeNexus.Events.EventTicket do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "event_tickets" do
    field :ticket_number, :integer
    field :payment_type, :string
    field :amount_cents, :integer
    field :stripe_payment_intent_id, :string
    field :status, :string, default: "valid"

    belongs_to :event, ForgeNexus.Events.Event
    belongs_to :user, ForgeNexus.Accounts.User
    belongs_to :community, ForgeNexus.Communities.Community

    timestamps()
  end

  def changeset(ticket, attrs) do
    ticket
    |> cast(attrs, [:event_id, :user_id, :community_id, :ticket_number, :payment_type,
                     :amount_cents, :stripe_payment_intent_id, :status])
    |> validate_required([:event_id, :user_id])
    |> validate_inclusion(:status, ~w(valid used cancelled refunded))
    |> validate_inclusion(:payment_type, ~w(free points money))
    |> unique_constraint([:event_id, :user_id])
  end
end
