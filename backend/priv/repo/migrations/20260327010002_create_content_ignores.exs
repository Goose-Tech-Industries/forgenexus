defmodule ForgeNexus.Repo.Migrations.CreateContentIgnores do
  use Ecto.Migration

  def change do
    create table(:content_ignores, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :forum_id, references(:forums, type: :binary_id, on_delete: :delete_all)
      add :thread_id, references(:threads, type: :binary_id, on_delete: :delete_all)

      timestamps()
    end

    create unique_index(:content_ignores, [:user_id, :forum_id], where: "forum_id IS NOT NULL", name: :content_ignores_user_forum)
    create unique_index(:content_ignores, [:user_id, :thread_id], where: "thread_id IS NOT NULL", name: :content_ignores_user_thread)
    create index(:content_ignores, [:user_id])
  end
end
