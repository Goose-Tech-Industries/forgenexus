defmodule ForgeNexus.Repo.Migrations.CreateQuarantineRecords do
  use Ecto.Migration

  def change do
    create table(:quarantine_records, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :quarantined_by_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :original_group_ids, {:array, :binary_id}, default: [], null: false
      add :reason, :text
      add :quarantined_at, :utc_datetime_usec, null: false
      add :released_at, :utc_datetime_usec

      timestamps()
    end

    create index(:quarantine_records, [:user_id])
    create index(:quarantine_records, [:user_id, :released_at])
  end
end
