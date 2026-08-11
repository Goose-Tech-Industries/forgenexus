defmodule ForgeNexus.Repo.Migrations.AddMyspaceProfilesAndAiFeatures do
  use Ecto.Migration

  def change do
    # MySpace-style profile blurbs + layout
    alter table(:users) do
      add :profile_mood, :string
      add :profile_mood_emoji, :string
      add :interests, :text
      add :favorite_music, :text
      add :favorite_movies, :text
      add :favorite_tv, :text
      add :favorite_games, :text
      add :favorite_books, :text
      add :heroes, :text
      add :who_id_like_to_meet, :text
      add :profile_layout, :string, default: "classic"

      add :profile_widget_order, {:array, :string},
        default: ["about", "top_friends", "guestbook", "activity", "achievements", "clips"]

      add :profile_song_autoplay, :boolean, default: false
      add :show_profile_views, :boolean, default: true
    end

    # Profile widgets (embeddable blocks on profile)
    create table(:profile_widgets, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :type, :string, null: false
      add :title, :string
      add :config, :jsonb, default: "{}"
      add :position, :integer, default: 0
      add :is_visible, :boolean, default: true

      timestamps()
    end

    create index(:profile_widgets, [:user_id])

    # AI thread summaries cache
    create table(:thread_summaries_ai, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :thread_id, references(:threads, type: :binary_id, on_delete: :delete_all), null: false
      add :community_id, references(:communities, type: :binary_id, on_delete: :delete_all)
      add :summary, :text, null: false
      add :post_count_at_generation, :integer
      add :model, :string
      add :generated_at, :utc_datetime

      timestamps()
    end

    create unique_index(:thread_summaries_ai, [:thread_id])

    # AI community health score
    create table(:community_health_scores, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :community_id, references(:communities, type: :binary_id, on_delete: :delete_all),
        null: false

      add :score, :float, null: false
      add :trend, :string
      add :components, :jsonb, default: "{}"
      add :calculated_at, :utc_datetime, null: false

      timestamps()
    end

    create index(:community_health_scores, [:community_id, :calculated_at])

    # Event ticketing
    alter table(:events) do
      add_if_not_exists :ticket_price_cents, :integer
      add_if_not_exists :ticket_currency, :string, default: "usd"
      add_if_not_exists :ticket_points_price, :integer
      add_if_not_exists :max_tickets, :integer
      add_if_not_exists :tickets_sold, :integer, default: 0
      add_if_not_exists :is_ticketed, :boolean, default: false
    end

    create table(:event_tickets, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :event_id, references(:events, type: :binary_id, on_delete: :delete_all), null: false
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :community_id, references(:communities, type: :binary_id, on_delete: :delete_all)
      add :ticket_number, :integer
      add :payment_type, :string
      add :amount_cents, :integer
      add :stripe_payment_intent_id, :string
      add :status, :string, default: "valid"

      timestamps()
    end

    create unique_index(:event_tickets, [:event_id, :user_id])

    # Inline platform embeds - registered embed types
    create table(:platform_embeds, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :community_id, references(:communities, type: :binary_id, on_delete: :delete_all)
      add :type, :string, null: false
      add :reference_id, :binary_id, null: false
      add :embed_data, :jsonb, default: "{}"
      add :view_count, :integer, default: 0

      timestamps()
    end

    create index(:platform_embeds, [:type, :reference_id])
  end
end
