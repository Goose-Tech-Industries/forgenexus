defmodule ForgeNexus.Repo.Migrations.CommunitySubscriptions do
  use Ecto.Migration

  def change do
    # Stripe identifiers on the Community (one customer per community)
    alter table(:communities) do
      add :stripe_customer_id, :string
      add :plan_status, :string, default: "inactive"
      add :current_period_end, :utc_datetime
      add :cancel_at, :utc_datetime
    end

    create unique_index(:communities, [:stripe_customer_id])

    # Detailed subscription records (history + current). One row per Stripe
    # subscription object; community.plan/plan_status tracks the active row.
    create table(:community_subscriptions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :community_id, references(:communities, type: :binary_id, on_delete: :delete_all), null: false
      add :stripe_subscription_id, :string, null: false
      add :stripe_customer_id, :string
      add :stripe_price_id, :string
      add :plan, :string, null: false
      add :status, :string, null: false
      add :current_period_start, :utc_datetime
      add :current_period_end, :utc_datetime
      add :cancel_at_period_end, :boolean, default: false, null: false
      add :canceled_at, :utc_datetime
      add :metadata, :map, default: %{}

      timestamps()
    end

    create unique_index(:community_subscriptions, [:stripe_subscription_id])
    create index(:community_subscriptions, [:community_id])
    create index(:community_subscriptions, [:status])

    # Webhook event log for idempotency + audit trail.
    create table(:stripe_webhook_events, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :stripe_event_id, :string, null: false
      add :type, :string, null: false
      add :payload, :map, null: false
      add :processed_at, :utc_datetime

      timestamps()
    end

    create unique_index(:stripe_webhook_events, [:stripe_event_id])
    create index(:stripe_webhook_events, [:type])
  end
end
