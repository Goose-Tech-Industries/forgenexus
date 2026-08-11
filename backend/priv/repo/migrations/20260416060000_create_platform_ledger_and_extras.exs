defmodule ForgeNexus.Repo.Migrations.CreatePlatformLedgerAndExtras do
  use Ecto.Migration

  def change do
    # Platform ledger — tracks every dollar in/out with auto-split
    create table(:platform_ledger_entries, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :community_id, references(:communities, type: :binary_id, on_delete: :nilify_all)
      add :type, :string, null: false
      add :source, :string
      add :amount_cents, :integer, null: false
      add :infra_allocation_cents, :integer, null: false
      add :profit_allocation_cents, :integer, null: false
      add :reference_type, :string
      add :reference_id, :binary_id
      add :description, :string
      add :metadata, :jsonb, default: "{}"

      timestamps()
    end

    create index(:platform_ledger_entries, [:type])
    create index(:platform_ledger_entries, [:inserted_at])

    # Infra cost tracking
    create table(:infra_costs, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :provider, :string, null: false
      add :service, :string, null: false
      add :amount_cents, :integer, null: false
      add :currency, :string, default: "usd"
      add :period_start, :date, null: false
      add :period_end, :date, null: false
      add :is_recurring, :boolean, default: true
      add :notes, :string

      timestamps()
    end

    create index(:infra_costs, [:period_start])

    # Creator moderators — scoped permissions per creator
    create table(:creator_moderators, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :community_id, references(:communities, type: :binary_id, on_delete: :delete_all)
      add :creator_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :moderator_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :permissions, :jsonb, default: "{}", null: false

      timestamps()
    end

    create unique_index(:creator_moderators, [:creator_id, :moderator_id])
    create index(:creator_moderators, [:moderator_id])

    # Point packs — buy economy points with real money
    create table(:point_packs, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :community_id, references(:communities, type: :binary_id, on_delete: :delete_all)
      add :name, :string, null: false
      add :points, :integer, null: false
      add :bonus_points, :integer, default: 0
      add :price_cents, :integer, null: false
      add :currency, :string, default: "usd"
      add :is_active, :boolean, default: true
      add :position, :integer, default: 0
      add :emoji, :string

      timestamps()
    end

    create index(:point_packs, [:community_id])

    create table(:point_pack_purchases, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :pack_id, references(:point_packs, type: :binary_id, on_delete: :nilify_all)
      add :user_id, references(:users, type: :binary_id, on_delete: :nilify_all), null: false
      add :community_id, references(:communities, type: :binary_id, on_delete: :nilify_all)
      add :points_granted, :integer, null: false
      add :amount_cents, :integer, null: false
      add :stripe_payment_intent_id, :string
      add :status, :string, default: "completed"

      timestamps()
    end

    create index(:point_pack_purchases, [:user_id])

    # Persistent room flag + post paywall
    alter table(:voice_rooms) do
      add :is_persistent, :boolean, default: false
    end

    alter table(:posts) do
      add :paywall_tier_id,
          references(:subscription_tiers, type: :binary_id, on_delete: :nilify_all)
    end

    alter table(:threads) do
      add :paywall_tier_id,
          references(:subscription_tiers, type: :binary_id, on_delete: :nilify_all)
    end
  end
end
