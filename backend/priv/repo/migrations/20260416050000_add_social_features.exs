defmodule ForgeNexus.Repo.Migrations.AddSocialFeatures do
  use Ecto.Migration

  def change do
    # Profile song + rich presence + CSS sandbox on users
    alter table(:users) do
      add :profile_song_url, :string
      add :profile_song_title, :string
      add :profile_css, :text
      add :rich_presence_status, :string
      add :rich_presence_activity, :string
      add :rich_presence_detail, :string
      add :is_premium, :boolean, default: false
      add :premium_until, :utc_datetime
    end

    # Anonymous post flag on threads + posts
    alter table(:threads) do
      add :is_anonymous, :boolean, default: false
    end

    alter table(:posts) do
      add :is_anonymous, :boolean, default: false
    end

    # Poke/wink system
    create table(:pokes, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :community_id, references(:communities, type: :binary_id, on_delete: :delete_all)
      add :sender_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :recipient_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :type, :string, default: "poke"
      add :message, :string
      add :is_read, :boolean, default: false

      timestamps()
    end

    create index(:pokes, [:recipient_id, :is_read])
    create index(:pokes, [:sender_id])

    # User premium subscriptions
    create table(:user_premiums, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :plan, :string, default: "basic", null: false
      add :status, :string, default: "active", null: false
      add :started_at, :utc_datetime
      add :expires_at, :utc_datetime
      add :stripe_subscription_id, :string
      add :features, :jsonb, default: "{}"

      timestamps()
    end

    create unique_index(:user_premiums, [:user_id])

    create index(:user_premiums, [:stripe_subscription_id],
             where: "stripe_subscription_id IS NOT NULL"
           )

    # Community discovery / explore metadata
    alter table(:communities) do
      add :is_discoverable, :boolean, default: true
      add :tags, {:array, :string}, default: []
      add :category, :string
      add :activity_score, :float, default: 0.0
    end

    create index(:communities, [:is_discoverable, :activity_score])
  end
end
