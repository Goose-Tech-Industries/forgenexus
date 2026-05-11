defmodule ForgeNexus.Voice.Recording do
  @moduledoc """
  A recorded voice room session. Audio is stored locally (or in S3 in prod)
  and transcribed asynchronously via the configured transcription provider.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @transcript_statuses ~w(pending processing ready failed disabled)

  schema "voice_recordings" do
    field :title, :string
    field :description, :string
    field :audio_url, :string
    field :mime_type, :string, default: "audio/webm"
    field :size_bytes, :integer
    field :duration_seconds, :integer
    field :started_at, :utc_datetime
    field :ended_at, :utc_datetime
    field :is_public, :boolean, default: true
    field :transcript, :string
    field :transcript_status, :string, default: "pending"
    field :transcript_language, :string
    field :participant_count, :integer, default: 0

    belongs_to :community, ForgeNexus.Communities.Community
    belongs_to :room, ForgeNexus.Voice.Room
    belongs_to :host_user, ForgeNexus.Accounts.User

    timestamps()
  end

  def changeset(recording, attrs) do
    recording
    |> cast(attrs, [
      :room_id,
      :host_user_id,
      :title,
      :description,
      :audio_url,
      :mime_type,
      :size_bytes,
      :duration_seconds,
      :started_at,
      :ended_at,
      :is_public,
      :transcript,
      :transcript_status,
      :transcript_language,
      :participant_count
    ])
    |> validate_required([:room_id, :audio_url, :started_at])
    |> validate_inclusion(:transcript_status, @transcript_statuses)
  end

  def transcript_statuses, do: @transcript_statuses
end
