defmodule ForgeNexus.Voice.CallLog do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "voice_call_logs" do
    field :room_type, :string
    field :started_at, :utc_datetime
    field :ended_at, :utc_datetime
    field :participant_ids, {:array, :binary_id}, default: []
    field :peak_participants, :integer, default: 0
    field :peak_audience, :integer, default: 0
    field :peak_speakers, :integer, default: 0
    field :total_hand_raises, :integer, default: 0
    field :total_promotions, :integer, default: 0
    field :total_demotions, :integer, default: 0
    field :host_user_id, :binary_id

    belongs_to :community, ForgeNexus.Communities.Community
    belongs_to :room, ForgeNexus.Voice.Room

    timestamps()
  end

  def changeset(log, attrs) do
    log
    |> cast(attrs, [
      :room_id,
      :room_type,
      :started_at,
      :ended_at,
      :participant_ids,
      :peak_participants,
      :peak_audience,
      :peak_speakers,
      :total_hand_raises,
      :total_promotions,
      :total_demotions,
      :host_user_id
    ])
    |> validate_required([:started_at])
  end
end
