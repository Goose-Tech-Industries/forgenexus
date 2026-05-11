defmodule ForgeNexus.Repo.Migrations.AddPrivateThreadsForumPermissionsWebhooks do
  use Ecto.Migration

  def change do
    # === Nice-to-Have #8: Private Threads ===

    alter table(:threads) do
      add :is_private, :boolean, default: false, null: false
    end

    create table(:thread_participants, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :thread_id, references(:threads, type: :binary_id, on_delete: :delete_all), null: false
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :added_at, :utc_datetime, null: false
    end

    create unique_index(:thread_participants, [:thread_id, :user_id])
    create index(:thread_participants, [:user_id])

    # === Nice-to-Have #13: Forum-Specific Permissions ===

    create table(:forum_permissions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :forum_id, references(:forums, type: :binary_id, on_delete: :delete_all), null: false
      add :group_id, references(:user_groups, type: :binary_id, on_delete: :delete_all), null: false
      add :can_view, :boolean, default: true, null: false
      add :can_post, :boolean, default: true, null: false
      add :can_create_threads, :boolean, default: true, null: false

      timestamps()
    end

    create unique_index(:forum_permissions, [:forum_id, :group_id])
    create index(:forum_permissions, [:group_id])

    # === Nice-to-Have #15: Forum Webhooks ===

    create table(:forum_webhooks, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :url, :string, null: false
      add :secret, :string, null: false
      add :events, {:array, :string}, default: [], null: false
      add :is_active, :boolean, default: true, null: false
      add :last_triggered_at, :utc_datetime
      add :failure_count, :integer, default: 0, null: false

      add :created_by_id, references(:users, type: :binary_id, on_delete: :nilify_all)

      timestamps()
    end

    create index(:forum_webhooks, [:is_active])
  end
end
