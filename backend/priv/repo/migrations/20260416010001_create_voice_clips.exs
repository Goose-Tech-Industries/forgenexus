defmodule ForgeNexus.Repo.Migrations.CreateVoiceClips do
  use Ecto.Migration

  def change do
    create table(:voice_clips, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :recording_id, references(:voice_recordings, type: :binary_id, on_delete: :delete_all),
        null: false

      add :created_by_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :title, :string
      add :start_ms, :integer, null: false
      add :end_ms, :integer, null: false
      add :view_count, :integer, default: 0
      add :is_public, :boolean, default: true

      timestamps()
    end

    create index(:voice_clips, [:recording_id])
    create index(:voice_clips, [:created_by_id])
    create index(:voice_clips, [:inserted_at])
  end
end
