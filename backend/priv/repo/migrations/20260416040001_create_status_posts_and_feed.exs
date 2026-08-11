defmodule ForgeNexus.Repo.Migrations.CreateStatusPostsAndFeed do
  use Ecto.Migration

  def change do
    create table(:status_posts, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :community_id, references(:communities, type: :binary_id, on_delete: :delete_all)
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      add :body, :text, null: false
      add :media_urls, {:array, :string}, default: []
      add :media_type, :string, default: "text"

      add :reference_type, :string
      add :reference_id, :binary_id

      add :like_count, :integer, default: 0
      add :comment_count, :integer, default: 0
      add :share_count, :integer, default: 0

      add :is_pinned, :boolean, default: false
      add :visibility, :string, default: "public"

      timestamps()
    end

    create index(:status_posts, [:community_id, :inserted_at])
    create index(:status_posts, [:user_id])
    create index(:status_posts, [:is_pinned])

    create table(:status_post_comments, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :status_post_id, references(:status_posts, type: :binary_id, on_delete: :delete_all),
        null: false

      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :body, :text, null: false

      timestamps()
    end

    create index(:status_post_comments, [:status_post_id])

    create table(:status_post_likes, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :status_post_id, references(:status_posts, type: :binary_id, on_delete: :delete_all),
        null: false

      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      timestamps()
    end

    create unique_index(:status_post_likes, [:status_post_id, :user_id])
  end
end
