defmodule ForgeNexus.Repo.Migrations.CreateChatLayer2 do
  use Ecto.Migration

  def change do
    # 1. Chat mentions
    create table(:chat_mentions, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :message_id, references(:chat_messages, type: :binary_id, on_delete: :delete_all),
        null: false

      add :mentioned_user_id, references(:users, type: :binary_id, on_delete: :delete_all),
        null: false

      add :mention_type, :string, default: "user"
      add :read, :boolean, default: false
      timestamps()
    end

    create index(:chat_mentions, [:mentioned_user_id, :read])
    create index(:chat_mentions, [:message_id])
    create unique_index(:chat_mentions, [:message_id, :mentioned_user_id])

    # 2. Message edit history
    create table(:chat_message_edits, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :message_id, references(:chat_messages, type: :binary_id, on_delete: :delete_all),
        null: false

      add :previous_body, :text, null: false
      add :edited_by_id, references(:users, type: :binary_id, on_delete: :nilify_all), null: false
      timestamps()
    end

    create index(:chat_message_edits, [:message_id])

    # 3. Enhance notifications table with target fields
    alter table(:notifications) do
      add :link, :string
      add :target_type, :string
      add :target_id, :binary_id
    end

    # 4. User status fields
    alter table(:users) do
      add :presence_status, :string, default: "online"
      add :custom_status_text, :string
      add :custom_status_emoji, :string
      add :auto_away_at, :utc_datetime
    end
  end
end
