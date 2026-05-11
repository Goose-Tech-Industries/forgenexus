defmodule ForgeNexus.Social.WatchAlong do
  @moduledoc """
  Watch Along — synchronized external content viewing (PPV, sports, shows).
  The platform provides the social layer (voice, chat, predictions, reactions).
  Users watch on their own licensed service (Peacock, ESPN+, FITE, etc.).

  Segments represent individual matches/acts/segments of a show, each with
  its own prediction market and discussion thread.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @statuses ~w(upcoming live completed cancelled)
  @show_types ~w(wrestling ppv sports esports movie tv_premiere gaming_event custom)

  schema "watch_alongs" do
    field :title, :string
    field :description, :string
    field :show_type, :string
    field :starts_at, :utc_datetime
    field :status, :string, default: "upcoming"
    field :segments, {:array, :map}, default: []
    field :current_segment, :integer, default: 0

    belongs_to :community, ForgeNexus.Communities.Community
    belongs_to :room, ForgeNexus.Voice.Room
    belongs_to :created_by, ForgeNexus.Accounts.User

    timestamps()
  end

  def changeset(wa, attrs) do
    wa
    |> cast(attrs, [:community_id, :room_id, :created_by_id, :title, :description,
                     :show_type, :starts_at, :status, :segments, :current_segment])
    |> validate_required([:title, :starts_at])
    |> validate_inclusion(:status, @statuses)
    |> validate_inclusion(:show_type, @show_types)
  end

  def show_types, do: @show_types

  def example_wrestling_segments do
    [
      %{"name" => "Pre-Show Panel", "type" => "segment", "prediction_id" => nil},
      %{"name" => "Match 1: Tag Team Championship", "type" => "match", "prediction_id" => nil,
        "participants" => ["Team A", "Team B"]},
      %{"name" => "Match 2: Women's Championship", "type" => "match", "prediction_id" => nil,
        "participants" => ["Wrestler A", "Wrestler B"]},
      %{"name" => "Main Event: World Championship", "type" => "match", "prediction_id" => nil,
        "participants" => ["Champion", "Challenger"]}
    ]
  end
end
