defmodule ForgeNexus.Repo.Migrations.CreateApiKeysAndFinalFeatures do
  use Ecto.Migration

  def change do
    # API keys for third-party developers
    create table(:api_keys, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :community_id, references(:communities, type: :binary_id, on_delete: :delete_all)
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :key_hash, :string, null: false
      add :key_prefix, :string, null: false
      add :scopes, {:array, :string}, default: ["read"]
      add :rate_limit_per_minute, :integer, default: 100
      add :plan, :string, default: "free"
      add :is_active, :boolean, default: true
      add :last_used_at, :utc_datetime
      add :total_requests, :integer, default: 0
      add :expires_at, :utc_datetime

      timestamps()
    end

    create unique_index(:api_keys, [:key_hash])
    create index(:api_keys, [:user_id])
    create index(:api_keys, [:community_id])

    # API usage log (for billing + analytics)
    create table(:api_usage_daily, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :api_key_id, references(:api_keys, type: :binary_id, on_delete: :delete_all),
        null: false

      add :date, :date, null: false
      add :request_count, :integer, default: 0
      add :error_count, :integer, default: 0

      timestamps()
    end

    create unique_index(:api_usage_daily, [:api_key_id, :date])

    # Thread-voice linking
    alter table(:voice_rooms) do
      add :linked_thread_id, references(:threads, type: :binary_id, on_delete: :nilify_all)
    end

    # Subscription-gated voice rooms
    alter table(:voice_rooms) do
      add :required_tier_id,
          references(:subscription_tiers, type: :binary_id, on_delete: :nilify_all)
    end
  end
end
