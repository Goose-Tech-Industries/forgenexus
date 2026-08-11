defmodule ForgeNexus.Repo.Migrations.CreateMessaging do
  use Ecto.Migration

  def change do
    # Conversations (supports 1:1 and group chats)
    create table(:conversations, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :title, :string
      add :type, :string, null: false, default: "direct"
      add :last_message_at, :utc_datetime
      add :message_count, :integer, default: 0
      add :creator_id, references(:users, type: :binary_id, on_delete: :nilify_all)

      timestamps()
    end

    create index(:conversations, [:type])
    create index(:conversations, [:last_message_at])

    # Conversation participants
    create table(:conversation_participants, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :role, :string, default: "member"
      add :last_read_at, :utc_datetime
      add :is_muted, :boolean, default: false
      add :joined_at, :utc_datetime, null: false

      add :conversation_id, references(:conversations, type: :binary_id, on_delete: :delete_all),
        null: false

      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      timestamps()
    end

    create unique_index(:conversation_participants, [:conversation_id, :user_id])
    create index(:conversation_participants, [:user_id])

    # Messages
    create table(:messages, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :body, :text, null: false
      add :body_html, :text
      add :is_edited, :boolean, default: false
      add :edited_at, :utc_datetime
      add :is_system, :boolean, default: false

      add :conversation_id, references(:conversations, type: :binary_id, on_delete: :delete_all),
        null: false

      add :user_id, references(:users, type: :binary_id, on_delete: :nilify_all), null: false
      add :reply_to_id, references(:messages, type: :binary_id, on_delete: :nilify_all)

      timestamps()
    end

    create index(:messages, [:conversation_id])
    create index(:messages, [:user_id])
    create index(:messages, [:conversation_id, :inserted_at])

    # Notifications
    create table(:notifications, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :type, :string, null: false
      add :title, :string, null: false
      add :body, :text
      add :is_read, :boolean, default: false
      add :read_at, :utc_datetime
      add :url, :string
      add :metadata, :map, default: %{}
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :actor_id, references(:users, type: :binary_id, on_delete: :nilify_all)

      timestamps()
    end

    create index(:notifications, [:user_id, :is_read])
    create index(:notifications, [:user_id, :inserted_at])

    # User blocks
    create table(:user_blocks, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      add :blocked_user_id, references(:users, type: :binary_id, on_delete: :delete_all),
        null: false

      timestamps()
    end

    create unique_index(:user_blocks, [:user_id, :blocked_user_id])

    # Friend/buddy list
    create table(:friendships, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :status, :string, default: "pending"
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :friend_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      timestamps()
    end

    create unique_index(:friendships, [:user_id, :friend_id])
    create index(:friendships, [:friend_id])
    create index(:friendships, [:status])
  end
end
