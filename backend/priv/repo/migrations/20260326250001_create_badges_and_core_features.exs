defmodule ForgeNexus.Repo.Migrations.CreateBadgesAndCoreFeatures do
  use Ecto.Migration

  def change do
    # === Feature 2: Awards/Badges ===
    create table(:badges, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :description, :string
      add :icon_url, :string
      add :icon_emoji, :string
      add :color, :string
      # achievement, milestone, admin_granted, event
      add :category, :string, default: "achievement"
      # auto-awarded by system
      add :is_auto, :boolean, default: false
      # e.g. %{type: "post_count", value: 100}
      add :auto_criteria, :map
      add :position, :integer, default: 0
      add :is_active, :boolean, default: true

      timestamps()
    end

    create unique_index(:badges, [:name])

    create table(:user_badges, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :badge_id, references(:badges, type: :binary_id, on_delete: :delete_all), null: false
      add :awarded_by_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :reason, :string
      # shown on profile/posts
      add :is_featured, :boolean, default: false

      timestamps()
    end

    create unique_index(:user_badges, [:user_id, :badge_id])
    create index(:user_badges, [:user_id])

    # === Feature 3: Best Answer / Solved ===
    alter table(:threads) do
      add :solved_post_id, references(:posts, type: :binary_id, on_delete: :nilify_all)
      add :is_solved, :boolean, default: false
    end

    # === Feature 4: Thread Prefixes/Tags ===
    create table(:thread_prefixes, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :color, :string, default: "#6366f1"
      add :bg_color, :string
      add :forum_id, references(:forums, type: :binary_id, on_delete: :delete_all)
      # available in all forums
      add :is_global, :boolean, default: false
      add :position, :integer, default: 0

      timestamps()
    end

    create index(:thread_prefixes, [:forum_id])

    alter table(:threads) do
      add :prefix_id, references(:thread_prefixes, type: :binary_id, on_delete: :nilify_all)
    end

    # === Feature 5: User Ignore/Block ===
    # user_blocks table already exists from previous migration

    # === Feature 6: Draft Auto-Save ===
    create table(:post_drafts, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      # "thread_create", "thread_reply", "dm"
      add :context_type, :string, null: false
      # forum_id for create, thread_id for reply
      add :context_id, :string
      # for thread_create drafts
      add :title, :string
      add :body, :text, null: false

      timestamps()
    end

    create unique_index(:post_drafts, [:user_id, :context_type, :context_id])
  end
end
