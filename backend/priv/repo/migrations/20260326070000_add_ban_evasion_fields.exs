defmodule ForgeNexus.Repo.Migrations.AddBanEvasionFields do
  use Ecto.Migration

  def change do
    create table(:suspicious_accounts, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      add :linked_user_id, references(:users, type: :binary_id, on_delete: :delete_all),
        null: false

      add :match_type, :string, null: false
      add :confidence, :float, null: false, default: 0.0
      add :reviewed, :boolean, default: false
      add :reviewed_by_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :reviewed_at, :utc_datetime

      timestamps()
    end

    create index(:suspicious_accounts, [:user_id])
    create index(:suspicious_accounts, [:linked_user_id])
    create index(:suspicious_accounts, [:reviewed])
    create unique_index(:suspicious_accounts, [:user_id, :linked_user_id, :match_type])

    create table(:impersonation_logs, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :admin_id, references(:users, type: :binary_id, on_delete: :nilify_all), null: false

      add :target_user_id, references(:users, type: :binary_id, on_delete: :delete_all),
        null: false

      add :reason, :text, null: false
      add :started_at, :utc_datetime, null: false
      add :ended_at, :utc_datetime

      timestamps()
    end

    create index(:impersonation_logs, [:admin_id])
    create index(:impersonation_logs, [:target_user_id])
    create index(:impersonation_logs, [:ended_at])
  end
end
