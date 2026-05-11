defmodule ForgeNexus.Repo.Migrations.CreateKnowledgeBase do
  use Ecto.Migration

  def change do
    # Wiki Categories
    create table(:wiki_categories, primary_key: false) do
      add :id, :binary_id, primary_key: true, autogenerate: true
      add :name, :string, null: false
      add :slug, :string, null: false
      add :description, :text
      add :parent_id, references(:wiki_categories, type: :binary_id, on_delete: :nilify_all)
      add :position, :integer, default: 0
      add :icon, :string
      add :is_visible, :boolean, default: true

      timestamps(type: :utc_datetime)
    end

    create unique_index(:wiki_categories, [:slug])
    create index(:wiki_categories, [:parent_id])
    create index(:wiki_categories, [:position])
    create index(:wiki_categories, [:is_visible])

    # Wiki Pages
    create table(:wiki_pages, primary_key: false) do
      add :id, :binary_id, primary_key: true, autogenerate: true
      add :title, :string, null: false
      add :slug, :string, null: false
      add :body, :text, null: false
      add :body_html, :text
      add :category_id, references(:wiki_categories, type: :binary_id, on_delete: :nilify_all)
      add :created_by_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :last_edited_by_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :edit_permission, :string, default: "members"
      add :allowed_group_ids, :map, default: "[]"
      add :is_published, :boolean, default: true
      add :is_locked, :boolean, default: false
      add :view_count, :integer, default: 0
      add :source_thread_id, references(:threads, type: :binary_id, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create unique_index(:wiki_pages, [:slug])
    create index(:wiki_pages, [:category_id])
    create index(:wiki_pages, [:created_by_id])
    create index(:wiki_pages, [:last_edited_by_id])
    create index(:wiki_pages, [:is_published])
    create index(:wiki_pages, [:source_thread_id])

    # Wiki Revisions
    create table(:wiki_revisions, primary_key: false) do
      add :id, :binary_id, primary_key: true, autogenerate: true
      add :page_id, references(:wiki_pages, type: :binary_id, on_delete: :delete_all)
      add :body, :text, null: false
      add :body_html, :text
      add :edit_summary, :string
      add :edited_by_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :revision_number, :integer, null: false
      add :inserted_at, :utc_datetime, null: false
    end

    create unique_index(:wiki_revisions, [:page_id, :revision_number])
    create index(:wiki_revisions, [:edited_by_id])

    # Wiki Edit Locks
    create table(:wiki_edit_locks, primary_key: false) do
      add :id, :binary_id, primary_key: true, autogenerate: true
      add :page_id, references(:wiki_pages, type: :binary_id, on_delete: :delete_all)
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all)
      add :locked_at, :utc_datetime, null: false
      add :expires_at, :utc_datetime, null: false
    end

    create unique_index(:wiki_edit_locks, [:page_id])
    create index(:wiki_edit_locks, [:user_id])
    create index(:wiki_edit_locks, [:expires_at])
  end
end
