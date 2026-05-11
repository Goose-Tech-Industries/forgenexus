defmodule ForgeNexus.Repo.Migrations.CreateAdminAuditLogs do
  use Ecto.Migration

  def change do
    create table(:admin_audit_logs, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :action, :string, null: false
      add :category, :string, null: false
      add :target_type, :string
      add :target_id, :binary_id
      add :description, :string
      add :previous_state, :map, default: %{}
      add :new_state, :map, default: %{}
      add :is_rolled_back, :boolean, default: false
      add :rolled_back_at, :utc_datetime
      add :rolled_back_by_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :admin_id, references(:users, type: :binary_id, on_delete: :nilify_all), null: false

      timestamps()
    end

    create index(:admin_audit_logs, [:admin_id])
    create index(:admin_audit_logs, [:action])
    create index(:admin_audit_logs, [:category])
    create index(:admin_audit_logs, [:inserted_at])
  end
end
