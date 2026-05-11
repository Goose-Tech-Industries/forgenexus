defmodule ForgeNexus.Repo.Migrations.AddScheduledPostsAndReputationEvents do
  use Ecto.Migration

  def change do
    # --- Scheduled Posts: add fields to threads ---
    alter table(:threads) do
      add :scheduled_at, :utc_datetime
      add :status, :string, default: "published"
    end

    create index(:threads, [:status, :scheduled_at],
      where: "status = 'scheduled' AND scheduled_at IS NOT NULL",
      name: :threads_scheduled_at_pending_idx
    )

    # --- Reputation Events ---
    create table(:reputation_events, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :event_type, :string, null: false
      add :points, :integer, null: false
      add :source_type, :string
      add :source_id, :binary_id

      timestamps(updated_at: false)
    end

    create index(:reputation_events, [:user_id])
    create index(:reputation_events, [:user_id, :event_type])
    create index(:reputation_events, [:source_type, :source_id])
  end
end
