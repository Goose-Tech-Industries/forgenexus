defmodule ForgeNexus.Repo.Migrations.CreateAppeals do
  use Ecto.Migration

  def change do
    create table(:appeals, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :type, :string, null: false
      add :target_id, :binary_id, null: false
      add :reason, :text, null: false
      add :status, :string, null: false, default: "pending"
      add :decision_note, :text
      add :decided_at, :utc_datetime
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :reviewer_id, references(:users, type: :binary_id, on_delete: :nilify_all)

      timestamps()
    end

    create index(:appeals, [:user_id])
    create index(:appeals, [:reviewer_id])
    create index(:appeals, [:status])
    create index(:appeals, [:type, :target_id])
  end
end
