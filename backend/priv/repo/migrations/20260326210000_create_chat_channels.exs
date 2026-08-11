defmodule ForgeNexus.Repo.Migrations.CreateChatChannels do
  use Ecto.Migration

  def change do
    # Channel categories (General, Gaming, Staff-Only, etc.)
    create table(:chat_channel_categories, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :slug, :string, null: false
      add :position, :integer, default: 0
      add :is_collapsed, :boolean, default: false
      timestamps()
    end

    create unique_index(:chat_channel_categories, [:slug])

    # Chat channels
    create table(:chat_channels, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :slug, :string, null: false
      add :description, :string
      add :topic, :string
      add :type, :string, default: "text"
      add :icon, :string
      add :color, :string
      add :position, :integer, default: 0

      add :category_id,
          references(:chat_channel_categories, type: :binary_id, on_delete: :nilify_all)

      # Permissions
      add :is_private, :boolean, default: false
      add :allowed_group_ids, {:array, :binary_id}, default: []
      add :is_read_only, :boolean, default: false
      add :slowmode_seconds, :integer, default: 0
      add :is_nsfw, :boolean, default: false
      add :is_archived, :boolean, default: false

      # Metadata
      add :last_message_at, :utc_datetime
      add :message_count, :integer, default: 0
      add :created_by_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      timestamps()
    end

    create unique_index(:chat_channels, [:slug])
    create index(:chat_channels, [:category_id])

    # Channel messages
    create table(:chat_messages, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :body, :text, null: false

      add :channel_id, references(:chat_channels, type: :binary_id, on_delete: :delete_all),
        null: false

      add :user_id, references(:users, type: :binary_id, on_delete: :nilify_all), null: false

      # Features
      add :is_edited, :boolean, default: false
      add :edited_at, :utc_datetime
      add :is_pinned, :boolean, default: false
      add :pinned_by_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :pinned_at, :utc_datetime
      add :is_deleted, :boolean, default: false
      add :deleted_by_id, references(:users, type: :binary_id, on_delete: :nilify_all)

      # Reply threading
      add :reply_to_id, references(:chat_messages, type: :binary_id, on_delete: :nilify_all)

      # Attachments & embeds
      add :attachments, {:array, :map}, default: []
      add :embeds, {:array, :map}, default: []

      timestamps()
    end

    create index(:chat_messages, [:channel_id, :inserted_at])
    create index(:chat_messages, [:user_id])
    create index(:chat_messages, [:reply_to_id])

    # Per-user channel state
    create table(:chat_channel_members, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :channel_id, references(:chat_channels, type: :binary_id, on_delete: :delete_all),
        null: false

      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :last_read_at, :utc_datetime

      add :last_read_message_id,
          references(:chat_messages, type: :binary_id, on_delete: :nilify_all)

      add :notification_level, :string, default: "all"
      add :is_muted, :boolean, default: false
      timestamps()
    end

    create unique_index(:chat_channel_members, [:channel_id, :user_id])
    create index(:chat_channel_members, [:user_id])

    # Message reactions
    create table(:chat_message_reactions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :emoji, :string, null: false

      add :message_id, references(:chat_messages, type: :binary_id, on_delete: :delete_all),
        null: false

      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      timestamps()
    end

    create unique_index(:chat_message_reactions, [:message_id, :user_id, :emoji])
    create index(:chat_message_reactions, [:message_id])
  end
end
