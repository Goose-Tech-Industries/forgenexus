defmodule ForgeNexus.Repo.Migrations.CreatePosts do
  use Ecto.Migration

  def change do
    # Posts
    create table(:posts, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :body, :text, null: false
      add :body_html, :text
      add :is_first_post, :boolean, default: false
      add :is_hidden, :boolean, default: false
      add :is_approved, :boolean, default: true
      add :is_edited, :boolean, default: false
      add :edited_at, :utc_datetime
      add :edited_by_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :edit_count, :integer, default: 0
      add :ip_address, :string
      add :like_count, :integer, default: 0
      add :thread_id, references(:threads, type: :binary_id, on_delete: :delete_all), null: false
      add :user_id, references(:users, type: :binary_id, on_delete: :nilify_all), null: false
      add :reply_to_id, references(:posts, type: :binary_id, on_delete: :nilify_all)
      add :position, :integer, default: 0

      timestamps()
    end

    create index(:posts, [:thread_id])
    create index(:posts, [:user_id])
    create index(:posts, [:thread_id, :position])
    create index(:posts, [:reply_to_id])
    create index(:posts, [:is_first_post])

    # Post edits history
    create table(:post_edits, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :body_before, :text, null: false
      add :body_after, :text, null: false
      add :reason, :string
      add :post_id, references(:posts, type: :binary_id, on_delete: :delete_all), null: false
      add :user_id, references(:users, type: :binary_id, on_delete: :nilify_all), null: false

      timestamps()
    end

    create index(:post_edits, [:post_id])

    # Attachments (polymorphic for posts and messages)
    create table(:attachments, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :filename, :string, null: false
      add :content_type, :string, null: false
      add :size, :integer, null: false
      add :url, :string, null: false
      add :thumbnail_url, :string
      add :width, :integer
      add :height, :integer
      add :attachable_type, :string, null: false
      add :attachable_id, :binary_id, null: false
      add :user_id, references(:users, type: :binary_id, on_delete: :nilify_all), null: false

      timestamps()
    end

    create index(:attachments, [:attachable_type, :attachable_id])
    create index(:attachments, [:user_id])

    # Thread subscriptions
    create table(:thread_subscriptions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :notification_level, :string, default: "watching"
      add :thread_id, references(:threads, type: :binary_id, on_delete: :delete_all), null: false
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      timestamps()
    end

    create unique_index(:thread_subscriptions, [:thread_id, :user_id])

    # Thread reads (tracking what users have read)
    create table(:thread_reads, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :last_read_post_id, references(:posts, type: :binary_id, on_delete: :delete_all)
      add :last_read_at, :utc_datetime, null: false
      add :thread_id, references(:threads, type: :binary_id, on_delete: :delete_all), null: false
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      timestamps()
    end

    create unique_index(:thread_reads, [:thread_id, :user_id])

    # Polls
    create table(:polls, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :question, :string, null: false
      add :is_multiple_choice, :boolean, default: false
      add :is_public, :boolean, default: true
      add :max_choices, :integer, default: 1
      add :closes_at, :utc_datetime
      add :voter_count, :integer, default: 0
      add :thread_id, references(:threads, type: :binary_id, on_delete: :delete_all), null: false

      timestamps()
    end

    create unique_index(:polls, [:thread_id])

    # Poll options
    create table(:poll_options, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :text, :string, null: false
      add :vote_count, :integer, default: 0
      add :position, :integer, default: 0
      add :poll_id, references(:polls, type: :binary_id, on_delete: :delete_all), null: false

      timestamps()
    end

    create index(:poll_options, [:poll_id])

    # Poll votes
    create table(:poll_votes, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :poll_id, references(:polls, type: :binary_id, on_delete: :delete_all), null: false

      add :option_id, references(:poll_options, type: :binary_id, on_delete: :delete_all),
        null: false

      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      timestamps()
    end

    create unique_index(:poll_votes, [:poll_id, :option_id, :user_id])
  end
end
