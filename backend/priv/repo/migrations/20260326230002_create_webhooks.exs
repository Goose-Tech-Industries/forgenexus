defmodule ForgeNexus.Repo.Migrations.CreateWebhooks do
  use Ecto.Migration

  def change do
    create table(:chat_webhooks, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :avatar_url, :string
      add :token, :string, null: false
      add :channel_id, references(:chat_channels, type: :binary_id, on_delete: :delete_all), null: false
      add :created_by_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :is_active, :boolean, default: true

      timestamps()
    end

    create unique_index(:chat_webhooks, [:token])
    create index(:chat_webhooks, [:channel_id])
  end
end
