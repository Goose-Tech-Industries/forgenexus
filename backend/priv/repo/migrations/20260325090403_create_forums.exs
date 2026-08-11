defmodule ForgeNexus.Repo.Migrations.CreateForums do
  use Ecto.Migration

  def change do
    # Categories (top-level grouping)
    create table(:categories, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :slug, :string, null: false
      add :description, :text
      add :icon, :string
      add :color, :string
      add :position, :integer, default: 0
      add :is_visible, :boolean, default: true
      add :parent_id, references(:categories, type: :binary_id, on_delete: :nilify_all)

      timestamps()
    end

    create unique_index(:categories, [:slug])
    create index(:categories, [:parent_id])
    create index(:categories, [:position])

    # Forums (within categories)
    create table(:forums, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :slug, :string, null: false
      add :description, :text
      add :icon, :string
      add :color, :string
      add :position, :integer, default: 0
      add :is_visible, :boolean, default: true
      add :is_locked, :boolean, default: false
      add :thread_count, :integer, default: 0
      add :post_count, :integer, default: 0
      add :last_post_at, :utc_datetime
      add :last_post_user_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :last_thread_id, :binary_id

      add :category_id, references(:categories, type: :binary_id, on_delete: :delete_all),
        null: false

      add :parent_id, references(:forums, type: :binary_id, on_delete: :nilify_all)
      add :permissions, :map, default: %{}

      timestamps()
    end

    create unique_index(:forums, [:slug])
    create index(:forums, [:category_id])
    create index(:forums, [:parent_id])
    create index(:forums, [:position])

    # Threads
    create table(:threads, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :title, :string, null: false
      add :slug, :string, null: false
      add :is_pinned, :boolean, default: false
      add :is_locked, :boolean, default: false
      add :is_hidden, :boolean, default: false
      add :is_approved, :boolean, default: true
      add :pin_position, :integer, default: 0
      add :view_count, :integer, default: 0
      add :reply_count, :integer, default: 0
      add :last_post_at, :utc_datetime
      add :last_post_user_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :forum_id, references(:forums, type: :binary_id, on_delete: :delete_all), null: false
      add :user_id, references(:users, type: :binary_id, on_delete: :nilify_all), null: false
      add :prefix, :string
      add :tags, {:array, :string}, default: []

      timestamps()
    end

    create index(:threads, [:forum_id])
    create index(:threads, [:user_id])
    create index(:threads, [:slug])
    create index(:threads, [:is_pinned, :last_post_at])
    create index(:threads, [:forum_id, :is_pinned, :last_post_at])
    create index(:threads, [:tags], using: :gin)
  end
end
