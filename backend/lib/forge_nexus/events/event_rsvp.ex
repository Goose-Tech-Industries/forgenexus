defmodule ForgeNexus.Events.EventRsvp do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "event_rsvps" do
    field :status, :string, default: "going"
    belongs_to :event, ForgeNexus.Events.Event
    belongs_to :user, ForgeNexus.Accounts.User
    timestamps()
  end

  def changeset(rsvp, attrs) do
    rsvp
    |> cast(attrs, [:event_id, :user_id, :status])
    |> validate_required([:event_id, :user_id])
    |> validate_inclusion(:status, ~w(going maybe not_going))
    |> unique_constraint([:event_id, :user_id])
  end
end
