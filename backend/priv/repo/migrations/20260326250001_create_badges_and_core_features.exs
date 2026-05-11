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
      add :category, :string, default: "achievement"  # achievement, milestone, admin_granted, event
      add :is_auto, :boolean, default: false  # auto-awarded by system
      add :auto_criteria, :map  # e.g. %{type: "post_count", value: 100}
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
      add :is_featured, :boolean, default: false  # shown on profile/posts

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
      add :is_global, :boolean, default: false  # available in all forums
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
      add :context_type, :string, null: false  # "thread_create", "thread_reply", "dm"
      add :context_id, :string  # forum_id for create, thread_id for reply
      add :title, :string  # for thread_create drafts
      add :body, :text, null: false

      timestamps()
    end

    create unique_index(:post_drafts, [:user_id, :context_type, :context_id])
  end
end
