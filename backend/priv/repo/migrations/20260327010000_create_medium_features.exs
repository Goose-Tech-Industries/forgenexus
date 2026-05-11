defmodule ForgeNexus.Repo.Migrations.CreateMediumFeatures do
  use Ecto.Migration

  def change do
    # === 8. Points/Currency ===
    alter table(:users) do
      add :points, :integer, default: 0
    end

    create table(:point_transactions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :amount, :integer, null: false
      add :balance_after, :integer, null: false
      add :reason, :string, null: false  # post_created, thread_created, reaction_received, badge_earned, admin_grant, purchase
      add :reference_type, :string  # post, thread, badge, item
      add :reference_id, :binary_id
      add :description, :string

      timestamps()
    end

    create index(:point_transactions, [:user_id, :inserted_at])

    create table(:point_config, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :action, :string, null: false
      add :points, :integer, null: false
      add :is_active, :boolean, default: true

      timestamps()
    end

    create unique_index(:point_config, [:action])

    # === 9. User Promotions ===
    create table(:promotion_rules, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :from_group_id, references(:user_groups, type: :binary_id, on_delete: :delete_all)
      add :to_group_id, references(:user_groups, type: :binary_id, on_delete: :delete_all), null: false
      add :criteria, :map, null: false  # %{post_count: 50, days_member: 30, reputation: 10, points: 500}
      add :is_active, :boolean, default: true
      add :position, :integer, default: 0

      timestamps()
    end

    create index(:promotion_rules, [:is_active])

    # === 10. Post Ratings ===
    create table(:post_ratings, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :post_id, references(:posts, type: :binary_id, on_delete: :delete_all), null: false
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :rating_type, :string, null: false  # agree, disagree, informative, funny, winner, useful

      timestamps()
    end

    create unique_index(:post_ratings, [:post_id, :user_id, :rating_type])
    create index(:post_ratings, [:post_id])
    create index(:post_ratings, [:user_id])

    # === 11. Calendar/Events ===
    create table(:events, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :title, :string, null: false
      add :description, :text
      add :location, :string
      add :event_type, :string, default: "community"  # community, contest, tournament, stream, meetup, custom
      add :starts_at, :utc_datetime, null: false
      add :ends_at, :utc_datetime
      add :is_all_day, :boolean, default: false
      add :is_recurring, :boolean, default: false
      add :recurrence_rule, :string  # weekly, biweekly, monthly
      add :color, :string
      add :max_attendees, :integer
      add :forum_id, references(:forums, type: :binary_id, on_delete: :nilify_all)
      add :created_by_id, references(:users, type: :binary_id, on_delete: :nilify_all), null: false
      add :is_published, :boolean, default: true
      add :is_cancelled, :boolean, default: false

      timestamps()
    end

    create index(:events, [:starts_at])
    create index(:events, [:forum_id])

    create table(:event_rsvps, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :event_id, references(:events, type: :binary_id, on_delete: :delete_all), null: false
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :status, :string, default: "going"  # going, maybe, not_going

      timestamps()
    end

    create unique_index(:event_rsvps, [:event_id, :user_id])

    # === 12. Gallery/Media Albums ===
    create table(:albums, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :title, :string, null: false
      add :description, :string
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :is_public, :boolean, default: true
      add :cover_image_url, :string
      add :media_count, :integer, default: 0
      add :position, :integer, default: 0

      timestamps()
    end

    create index(:albums, [:user_id])

    create table(:media_items, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :album_id, references(:albums, type: :binary_id, on_delete: :delete_all), null: false
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :file_url, :string, null: false
      add :thumbnail_url, :string
      add :file_type, :string, default: "image"  # image, video, gif
      add :file_size, :integer
      add :width, :integer
      add :height, :integer
      add :caption, :string
      add :position, :integer, default: 0

      timestamps()
    end

    create index(:media_items, [:album_id])
    create index(:media_items, [:user_id])

    # === 14. Staff Applications ===
    create table(:staff_application_forms, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :title, :string, null: false
      add :description, :text
      add :fields, {:array, :map}, default: []  # [{label, type, required, options}]
      add :target_group_id, references(:user_groups, type: :binary_id, on_delete: :nilify_all)
      add :is_open, :boolean, default: true
      add :min_posts, :integer, default: 0
      add :min_days_member, :integer, default: 0

      timestamps()
    end

    create table(:staff_applications, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :form_id, references(:staff_application_forms, type: :binary_id, on_delete: :delete_all), null: false
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :answers, {:array, :map}, default: []  # [{field_label, value}]
      add :status, :string, default: "pending"  # pending, under_review, accepted, denied
      add :reviewer_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :review_note, :string
      add :reviewed_at, :utc_datetime

      timestamps()
    end

    create index(:staff_applications, [:form_id])
    create index(:staff_applications, [:user_id])
    create index(:staff_applications, [:status])
  end
end
