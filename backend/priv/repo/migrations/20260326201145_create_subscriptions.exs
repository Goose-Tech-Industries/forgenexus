defmodule ForgeNexus.Repo.Migrations.CreateSubscriptions do
  use Ecto.Migration

  def change do
    create table(:subscription_tiers, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :slug, :string, null: false
      add :tier_level, :integer, null: false
      add :description, :text
      add :price_monthly, :decimal, precision: 10, scale: 2
      add :price_yearly, :decimal, precision: 10, scale: 2
      add :color, :string
      add :icon, :string
      add :is_active, :boolean, default: true

      # Perks
      add :custom_username_color, :boolean, default: false
      add :custom_username_effects, :boolean, default: false
      add :animated_avatar, :boolean, default: false
      add :custom_banner, :boolean, default: false
      add :larger_uploads, :boolean, default: false
      add :upload_limit_mb, :integer, default: 10
      add :extended_bio, :boolean, default: false
      add :bio_char_limit, :integer, default: 500
      add :profile_music, :boolean, default: false
      add :custom_emoji_slots, :integer, default: 0
      add :exclusive_frames, {:array, :string}, default: []
      add :badge_text, :string
      add :priority_support, :boolean, default: false

      timestamps()
    end

    create unique_index(:subscription_tiers, [:slug])
    create unique_index(:subscription_tiers, [:tier_level])

    create table(:user_subscriptions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      add :tier_id, references(:subscription_tiers, type: :binary_id, on_delete: :restrict),
        null: false

      add :status, :string, default: "active"
      add :started_at, :utc_datetime
      add :expires_at, :utc_datetime
      add :cancelled_at, :utc_datetime
      add :payment_method, :string
      add :external_id, :string

      timestamps()
    end

    create index(:user_subscriptions, [:user_id])
    create index(:user_subscriptions, [:tier_id])

    execute(
      "CREATE UNIQUE INDEX one_active_sub_per_user ON user_subscriptions (user_id) WHERE status = 'active'",
      "DROP INDEX one_active_sub_per_user"
    )
  end
end
