defmodule ForgeNexus.Repo.Migrations.CreateWebhookDeliveries do
  use Ecto.Migration

  def change do
    create table(:webhook_deliveries, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :webhook_id, references(:forum_webhooks, type: :binary_id, on_delete: :delete_all), null: false
      add :event_type, :string, null: false
      add :payload, :map, null: false, default: %{}
      add :response_status, :integer
      add :response_body, :text
      add :latency_ms, :integer
      add :attempt, :integer, null: false, default: 1
      add :error, :string
      add :delivered_at, :utc_datetime, null: false

      timestamps()
    end

    create index(:webhook_deliveries, [:webhook_id])
    create index(:webhook_deliveries, [:event_type])
    create index(:webhook_deliveries, [:delivered_at])
  end
end
