defmodule ForgeNexus.Repo.Migrations.AddRemainingFeatures do
  use Ecto.Migration

  def change do
    # Walk-on sounds per user
    alter table(:users) do
      add :walk_on_sound_url, :string
      add :walk_on_sound_name, :string
    end

    # Tiered visual gifts
    create table(:gift_tiers, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :community_id, references(:communities, type: :binary_id, on_delete: :delete_all)
      add :name, :string, null: false
      add :emoji, :string
      add :tier, :string, null: false
      add :cost, :integer, null: false
      add :animation_type, :string, default: "float_up"
      add :animation_duration_ms, :integer, default: 3000
      add :color, :string
      add :sound_url, :string
      add :is_active, :boolean, default: true
      add :position, :integer, default: 0

      timestamps()
    end

    create index(:gift_tiers, [:community_id, :tier])

    create table(:gift_sends, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :gift_tier_id, references(:gift_tiers, type: :binary_id, on_delete: :nilify_all)
      add :sender_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :recipient_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :room_id, references(:voice_rooms, type: :binary_id, on_delete: :nilify_all)
      add :community_id, references(:communities, type: :binary_id, on_delete: :delete_all)
      add :combo_count, :integer, default: 1
      add :cost, :integer, null: false

      timestamps()
    end

    create index(:gift_sends, [:recipient_id, :inserted_at])

    # Watch Along (synced external content viewing)
    create table(:watch_alongs, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :community_id, references(:communities, type: :binary_id, on_delete: :delete_all)
      add :room_id, references(:voice_rooms, type: :binary_id, on_delete: :nilify_all)
      add :created_by_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :title, :string, null: false
      add :description, :text
      add :show_type, :string
      add :starts_at, :utc_datetime, null: false
      add :status, :string, default: "upcoming"
      add :segments, :jsonb, default: "[]"
      add :current_segment, :integer, default: 0

      timestamps()
    end

    create index(:watch_alongs, [:community_id, :starts_at])
    create index(:watch_alongs, [:status])

    # Icebreaker games / challenges
    create table(:icebreaker_challenges, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :community_id, references(:communities, type: :binary_id, on_delete: :delete_all)
      add :sender_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :recipient_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :type, :string, null: false
      add :question, :string
      add :options, :jsonb
      add :sender_answer, :string
      add :recipient_answer, :string
      add :points_reward, :integer, default: 5
      add :status, :string, default: "pending"

      timestamps()
    end

    create index(:icebreaker_challenges, [:recipient_id, :status])

    # Gift cards / vouchers
    create table(:gift_cards, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :community_id, references(:communities, type: :binary_id, on_delete: :delete_all)
      add :purchaser_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :redeemed_by_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :code, :string, null: false
      add :amount_cents, :integer
      add :points_amount, :integer
      add :type, :string, default: "points"
      add :status, :string, default: "active"
      add :redeemed_at, :utc_datetime
      add :expires_at, :utc_datetime

      timestamps()
    end

    create unique_index(:gift_cards, [:code])

    # Affiliate / referral tracking
    create table(:referrals, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :referrer_id, references(:users, type: :binary_id, on_delete: :nilify_all), null: false

      add :referred_community_id,
          references(:communities, type: :binary_id, on_delete: :nilify_all)

      add :referred_user_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :code, :string, null: false
      add :commission_rate, :float, default: 0.15
      add :commission_duration_months, :integer, default: 12
      add :total_earned_cents, :integer, default: 0
      add :status, :string, default: "active"

      timestamps()
    end

    create unique_index(:referrals, [:code])
    create index(:referrals, [:referrer_id])

    # Tournament brackets
    alter table(:tournaments) do
      add :bracket_type, :string, default: "single_elimination"
      add :bracket_data, :jsonb, default: "{}"
      add :prize_pool_cents, :integer, default: 0
      add :prize_pool_points, :integer, default: 0
      add :check_in_required, :boolean, default: true
      add :check_in_opens_minutes, :integer, default: 30
      add :linked_room_id, references(:voice_rooms, type: :binary_id, on_delete: :nilify_all)
    end

    alter table(:tournament_participants) do
      add_if_not_exists :checked_in, :boolean, default: false
      add_if_not_exists :checked_in_at, :utc_datetime
      add_if_not_exists :placement, :integer
      add_if_not_exists :prize_cents, :integer
      add_if_not_exists :prize_points, :integer
    end

    # Message scheduling
    create table(:scheduled_messages, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :community_id, references(:communities, type: :binary_id, on_delete: :delete_all)
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :channel_id, references(:chat_channels, type: :binary_id, on_delete: :delete_all)
      add :body, :text, null: false
      add :scheduled_at, :utc_datetime, null: false
      add :status, :string, default: "pending"

      timestamps()
    end

    create index(:scheduled_messages, [:scheduled_at, :status])
  end
end
