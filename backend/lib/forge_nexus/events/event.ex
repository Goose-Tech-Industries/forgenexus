defmodule ForgeNexus.Events.Event do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "events" do
    field :title, :string
    field :description, :string
    field :location, :string
    field :event_type, :string, default: "community"
    field :starts_at, :utc_datetime
    field :ends_at, :utc_datetime
    field :is_all_day, :boolean, default: false
    field :is_recurring, :boolean, default: false
    field :recurrence_rule, :string
    field :color, :string
    field :max_attendees, :integer
    field :is_published, :boolean, default: true
    field :is_cancelled, :boolean, default: false

    belongs_to :forum, ForgeNexus.Forums.Forum
    belongs_to :created_by, ForgeNexus.Accounts.User
    has_many :rsvps, ForgeNexus.Events.EventRsvp
    timestamps()
  end

  def changeset(event, attrs) do
    event
    |> cast(attrs, [:title, :description, :location, :event_type, :starts_at, :ends_at,
                     :is_all_day, :is_recurring, :recurrence_rule, :color, :max_attendees,
                     :forum_id, :created_by_id, :is_published, :is_cancelled])
    |> validate_required([:title, :starts_at, :created_by_id])
    |> validate_inclusion(:event_type, ~w(community contest tournament stream meetup custom))
  end
end
