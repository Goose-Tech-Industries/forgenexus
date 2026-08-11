defmodule ForgeNexus.Repo.Migrations.CreateVoiceRooms do
  use Ecto.Migration

  def change do
    create table(:voice_rooms, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :slug, :string, null: false
      # lounge, huddle, town_hall
      add :type, :string, default: "lounge"
      add :channel_id, references(:chat_channels, type: :binary_id, on_delete: :nilify_all)

      add :category_id,
          references(:chat_channel_categories, type: :binary_id, on_delete: :nilify_all)

      add :max_participants, :integer, default: 15
      add :is_locked, :boolean, default: false
      add :is_active, :boolean, default: true
      add :position, :integer, default: 0

      # Permissions
      add :is_private, :boolean, default: false
      add :allowed_group_ids, {:array, :binary_id}, default: []

      add :created_by_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      timestamps()
    end

    create unique_index(:voice_rooms, [:slug])
    create index(:voice_rooms, [:category_id])

    # Call history log
    create table(:voice_call_logs, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :room_id, references(:voice_rooms, type: :binary_id, on_delete: :nilify_all)
      add :room_type, :string
      add :started_at, :utc_datetime, null: false
      add :ended_at, :utc_datetime
      add :participant_ids, {:array, :binary_id}, default: []
      add :peak_participants, :integer, default: 0

      timestamps()
    end

    create index(:voice_call_logs, [:room_id])
  end
end
