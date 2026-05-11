defmodule ForgeNexus.Repo.Migrations.CreateSoundboardClips do
  use Ecto.Migration

  def change do
    create table(:soundboard_clips, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :room_id, references(:voice_rooms, type: :binary_id, on_delete: :delete_all)
      add :uploaded_by_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :name, :string, null: false
      add :emoji, :string
      add :audio_url, :string, null: false
      add :duration_ms, :integer
      add :size_bytes, :integer
      add :play_count, :integer, default: 0
      add :is_global, :boolean, default: false

      timestamps()
    end

    create index(:soundboard_clips, [:room_id])
    create index(:soundboard_clips, [:is_global])
  end
end
