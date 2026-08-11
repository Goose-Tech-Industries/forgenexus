defmodule ForgeNexus.Repo.Migrations.AddPartyGamesAndFinalFeatures do
  use Ecto.Migration

  def change do
    # Party games (Jackbox / Cards Against Humanity style)
    create table(:party_games, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :community_id, references(:communities, type: :binary_id, on_delete: :delete_all)
      add :room_id, references(:voice_rooms, type: :binary_id, on_delete: :nilify_all)
      add :host_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :game_type, :string, null: false
      add :status, :string, default: "lobby"
      add :settings, :jsonb, default: "{}"
      add :state, :jsonb, default: "{}"
      add :max_players, :integer, default: 10
      add :round_number, :integer, default: 0
      add :total_rounds, :integer, default: 5
      add :wager_enabled, :boolean, default: false
      add :wager_per_round, :integer, default: 0

      timestamps()
    end

    create index(:party_games, [:room_id])
    create index(:party_games, [:status])

    create table(:party_game_players, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :game_id, references(:party_games, type: :binary_id, on_delete: :delete_all),
        null: false

      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :score, :integer, default: 0
      add :is_active, :boolean, default: true

      timestamps()
    end

    create unique_index(:party_game_players, [:game_id, :user_id])

    # Soft-block with edit offer (moderation middle ground)
    create table(:soft_blocks, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :community_id, references(:communities, type: :binary_id, on_delete: :delete_all)
      add :post_id, references(:posts, type: :binary_id, on_delete: :delete_all)
      add :thread_id, references(:threads, type: :binary_id, on_delete: :nilify_all)
      add :moderator_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :author_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :reason, :text
      add :rule_violated, :string
      add :expires_at, :utc_datetime, null: false
      add :status, :string, default: "pending"
      add :edited_at, :utc_datetime
      add :original_body, :text

      timestamps()
    end

    create index(:soft_blocks, [:author_id, :status])
    create index(:soft_blocks, [:expires_at])

    # Template marketplace
    create table(:community_templates, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :creator_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :name, :string, null: false
      add :description, :text
      add :category, :string
      add :preview_url, :string
      add :template_data, :jsonb, null: false
      add :price_cents, :integer, default: 0
      add :is_free, :boolean, default: true
      add :install_count, :integer, default: 0
      add :rating, :float, default: 0.0
      add :is_published, :boolean, default: false

      timestamps()
    end

    create index(:community_templates, [:category])
    create index(:community_templates, [:is_published, :install_count])

    # Plugin marketplace pricing
    alter table(:js_plugins) do
      add_if_not_exists :price_cents, :integer, default: 0
      add_if_not_exists :is_marketplace, :boolean, default: false
      add_if_not_exists :install_count, :integer, default: 0
      add_if_not_exists :rating, :float, default: 0.0
      add_if_not_exists :revenue_share_percent, :integer, default: 70
    end

    # Cross-community syndication
    create table(:syndicated_posts, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :source_thread_id, references(:threads, type: :binary_id, on_delete: :delete_all)
      add :source_community_id, references(:communities, type: :binary_id, on_delete: :delete_all)
      add :target_community_id, references(:communities, type: :binary_id, on_delete: :delete_all)
      add :target_thread_id, references(:threads, type: :binary_id, on_delete: :nilify_all)
      add :syndicated_by_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :status, :string, default: "active"

      timestamps()
    end

    create index(:syndicated_posts, [:source_community_id])
    create index(:syndicated_posts, [:target_community_id])

    # Tournament broadcast (LiveKit Egress config)
    alter table(:tournaments) do
      add_if_not_exists :broadcast_enabled, :boolean, default: false
      add_if_not_exists :broadcast_layout, :string, default: "tournament"

      add_if_not_exists :commentary_room_id,
                        references(:voice_rooms, type: :binary_id, on_delete: :nilify_all)
    end
  end
end
