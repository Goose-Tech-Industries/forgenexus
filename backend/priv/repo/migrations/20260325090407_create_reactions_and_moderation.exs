defmodule ForgeNexus.Repo.Migrations.CreateReactionsAndModeration do
  use Ecto.Migration

  def change do
    # Reactions (likes, thanks, etc.)
    create table(:reactions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :type, :string, null: false, default: "like"
      add :reactable_type, :string, null: false
      add :reactable_id, :binary_id, null: false
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      timestamps()
    end

    create unique_index(:reactions, [:user_id, :reactable_type, :reactable_id, :type])
    create index(:reactions, [:reactable_type, :reactable_id])

    # Reports (flagging content)
    create table(:reports, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :reason, :string, null: false
      add :description, :text
      add :status, :string, default: "open"
      add :resolved_at, :utc_datetime
      add :reportable_type, :string, null: false
      add :reportable_id, :binary_id, null: false
      add :reporter_id, references(:users, type: :binary_id, on_delete: :nilify_all), null: false
      add :resolver_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :resolution_note, :text

      timestamps()
    end

    create index(:reports, [:status])
    create index(:reports, [:reportable_type, :reportable_id])
    create index(:reports, [:reporter_id])

    # Moderation log
    create table(:moderation_logs, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :action, :string, null: false
      add :reason, :text
      add :metadata, :map, default: %{}
      add :target_type, :string, null: false
      add :target_id, :binary_id, null: false
      add :moderator_id, references(:users, type: :binary_id, on_delete: :nilify_all), null: false

      timestamps()
    end

    create index(:moderation_logs, [:moderator_id])
    create index(:moderation_logs, [:target_type, :target_id])
    create index(:moderation_logs, [:action])

    # Warnings / sanctions
    create table(:warnings, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :type, :string, null: false, default: "warning"
      add :reason, :text, null: false
      add :points, :integer, default: 1
      add :expires_at, :utc_datetime
      add :is_active, :boolean, default: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :issued_by_id, references(:users, type: :binary_id, on_delete: :nilify_all), null: false

      timestamps()
    end

    create index(:warnings, [:user_id, :is_active])

    # Bans
    create table(:bans, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :type, :string, null: false, default: "temporary"
      add :reason, :text, null: false
      add :expires_at, :utc_datetime
      add :is_active, :boolean, default: true
      add :ip_address, :string
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all)
      add :banned_by_id, references(:users, type: :binary_id, on_delete: :nilify_all), null: false

      timestamps()
    end

    create index(:bans, [:user_id, :is_active])
    create index(:bans, [:ip_address])

    # Site settings (key-value store)
    create table(:settings, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :key, :string, null: false
      add :value, :text
      add :type, :string, default: "string"
      add :group, :string, default: "general"
      add :description, :text

      timestamps()
    end

    create unique_index(:settings, [:key])
    create index(:settings, [:group])
  end
end
