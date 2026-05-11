defmodule ForgeNexus.Repo.Migrations.CreateVoiceRecordings do
  use Ecto.Migration

  def change do
    create table(:voice_recordings, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :room_id, references(:voice_rooms, type: :binary_id, on_delete: :delete_all), null: false
      add :host_user_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :title, :string
      add :description, :text
      add :audio_url, :string, null: false
      add :mime_type, :string, default: "audio/webm", null: false
      add :size_bytes, :integer
      add :duration_seconds, :integer
      add :started_at, :utc_datetime, null: false
      add :ended_at, :utc_datetime
      add :is_public, :boolean, default: true, null: false
      add :transcript, :text
      add :transcript_status, :string, default: "pending", null: false
      add :transcript_language, :string
      add :participant_count, :integer, default: 0

      timestamps()
    end

    create index(:voice_recordings, [:room_id])
    create index(:voice_recordings, [:host_user_id])
    create index(:voice_recordings, [:started_at])
    create index(:voice_recordings, [:transcript_status])
  end
end
