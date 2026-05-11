defmodule ForgeNexus.Repo.Migrations.AddModerationEnhancements do
  use Ecto.Migration

  def change do
    # Mod notes — private staff notes on users
    create table(:mod_notes, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :body, :text, null: false
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :author_id, references(:users, type: :binary_id, on_delete: :nilify_all), null: false

      timestamps()
    end

    create index(:mod_notes, [:user_id])
    create index(:mod_notes, [:author_id])

    # Enhance reports table
    alter table(:reports) do
      add :priority, :integer, default: 0
      add :assigned_to_id, references(:users, type: :binary_id, on_delete: :nilify_all)
    end

    create index(:reports, [:assigned_to_id])
    create index(:reports, [:priority])
  end
end
