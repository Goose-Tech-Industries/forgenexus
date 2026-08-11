defmodule ForgeNexus.Repo.Migrations.CreateDmCalls do
  use Ecto.Migration

  def change do
    create table(:dm_calls, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :conversation_id, references(:conversations, type: :binary_id, on_delete: :delete_all),
        null: false

      add :caller_id, references(:users, type: :binary_id, on_delete: :nilify_all), null: false
      # ringing, active, ended, missed, declined
      add :status, :string, default: "ringing"
      # audio, video
      add :type, :string, default: "audio"
      add :started_at, :utc_datetime
      add :answered_at, :utc_datetime
      add :ended_at, :utc_datetime
      add :participant_ids, {:array, :binary_id}, default: []

      timestamps()
    end

    create index(:dm_calls, [:conversation_id])
    create index(:dm_calls, [:caller_id])
    create index(:dm_calls, [:status])
  end
end
