defmodule ForgeNexus.Repo.Migrations.CreateMessageBookmarks do
  use Ecto.Migration

  def change do
    create table(:chat_message_bookmarks, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :message_id, references(:chat_messages, type: :binary_id, on_delete: :delete_all), null: false
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :note, :string

      timestamps()
    end

    create unique_index(:chat_message_bookmarks, [:message_id, :user_id])
    create index(:chat_message_bookmarks, [:user_id])
  end
end
