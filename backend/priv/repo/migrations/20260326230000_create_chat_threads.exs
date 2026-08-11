defmodule ForgeNexus.Repo.Migrations.CreateChatThreads do
  use Ecto.Migration

  def change do
    create table(:chat_threads, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false

      add :channel_id, references(:chat_channels, type: :binary_id, on_delete: :delete_all),
        null: false

      add :parent_message_id,
          references(:chat_messages, type: :binary_id, on_delete: :delete_all),
          null: false

      add :created_by_id, references(:users, type: :binary_id, on_delete: :nilify_all),
        null: false

      add :is_archived, :boolean, default: false
      add :is_locked, :boolean, default: false
      add :message_count, :integer, default: 0
      add :last_message_at, :utc_datetime
      add :auto_archive_minutes, :integer, default: 1440

      timestamps()
    end

    create unique_index(:chat_threads, [:parent_message_id])
    create index(:chat_threads, [:channel_id])

    # Thread messages
    create table(:chat_thread_messages, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :body, :text, null: false

      add :thread_id, references(:chat_threads, type: :binary_id, on_delete: :delete_all),
        null: false

      add :user_id, references(:users, type: :binary_id, on_delete: :nilify_all), null: false
      add :is_edited, :boolean, default: false
      add :edited_at, :utc_datetime
      add :is_deleted, :boolean, default: false

      timestamps()
    end

    create index(:chat_thread_messages, [:thread_id, :inserted_at])

    # Thread members (for notification tracking)
    create table(:chat_thread_members, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :thread_id, references(:chat_threads, type: :binary_id, on_delete: :delete_all),
        null: false

      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :last_read_at, :utc_datetime

      timestamps()
    end

    create unique_index(:chat_thread_members, [:thread_id, :user_id])

    # Add thread_id to chat_messages for the "has thread" indicator
    alter table(:chat_messages) do
      add :thread_id, references(:chat_threads, type: :binary_id, on_delete: :nilify_all)
    end
  end
end
