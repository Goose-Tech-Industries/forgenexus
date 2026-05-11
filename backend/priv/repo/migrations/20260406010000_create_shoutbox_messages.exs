defmodule ForgeNexus.Repo.Migrations.CreateShoutboxMessages do
  use Ecto.Migration

  def change do
    create table(:shoutbox_messages, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :body, :text, null: false
      add :body_html, :text
      add :is_pinned, :boolean, default: false
      add :is_system, :boolean, default: false
      add :is_deleted, :boolean, default: false

      timestamps()
    end

    create index(:shoutbox_messages, [:inserted_at])
    create index(:shoutbox_messages, [:user_id])
    create index(:shoutbox_messages, [:is_pinned])
  end
end
