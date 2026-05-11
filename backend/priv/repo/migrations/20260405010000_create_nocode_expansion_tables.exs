defmodule ForgeNexus.Repo.Migrations.CreateNocodeExpansionTables do
  use Ecto.Migration

  def change do
    # ========================================
    # SLASH COMMANDS
    # ========================================

    create_if_not_exists table(:slash_commands, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :description, :text
      add :category, :string
      add :flow_id, references(:flows, type: :binary_id, on_delete: :nilify_all)
      add :enabled, :boolean, default: true
      add :cooldown_seconds, :integer, default: 0
      add :permission_level, :string, default: "everyone"
      add :usage_count, :integer, default: 0
      add :is_built_in, :boolean, default: false
      add :response_type, :string, default: "channel"

      timestamps()
    end

    create_if_not_exists unique_index(:slash_commands, [:name])

    # ========================================
    # ECONOMY
    # ========================================

    create_if_not_exists table(:currencies, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :slug, :string, null: false
      add :symbol, :string
      add :description, :text
      add :is_default, :boolean, default: false
      add :is_tradeable, :boolean, default: true
      add :decimal_places, :integer, default: 0

      timestamps()
    end

    create_if_not_exists unique_index(:currencies, [:slug])

    create_if_not_exists table(:user_balances, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :currency_id, references(:currencies, type: :binary_id, on_delete: :delete_all), null: false
      add :balance, :bigint, default: 0
      add :lifetime_earned, :bigint, default: 0

      timestamps()
    end

    create_if_not_exists unique_index(:user_balances, [:user_id, :currency_id])

    create_if_not_exists table(:transactions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :from_user_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :to_user_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :currency_id, references(:currencies, type: :binary_id, on_delete: :delete_all), null: false
      add :amount, :bigint, null: false
      add :transaction_type, :string, null: false
      add :description, :text
      add :metadata, :map, default: %{}

      timestamps()
    end

    create_if_not_exists index(:transactions, [:from_user_id])
    create_if_not_exists index(:transactions, [:to_user_id])
    create_if_not_exists index(:transactions, [:currency_id])

    # ========================================
    # ITEMS & INVENTORY
    # ========================================

    create_if_not_exists table(:item_templates, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :slug, :string, null: false
      add :description, :text
      add :icon, :string
      add :rarity, :string, default: "common"
      add :category, :string
      add :properties, :map, default: %{}
      add :is_tradeable, :boolean, default: true
      add :is_stackable, :boolean, default: true
      add :is_consumable, :boolean, default: false
      add :max_stack, :integer, default: 99
      add :durability_max, :integer
      add :price, :bigint
      add :currency_id, references(:currencies, type: :binary_id, on_delete: :nilify_all)

      timestamps()
    end

    create_if_not_exists unique_index(:item_templates, [:slug])

    create_if_not_exists table(:user_inventory, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :item_template_id, references(:item_templates, type: :binary_id, on_delete: :delete_all), null: false
      add :quantity, :integer, default: 1
      add :durability, :integer
      add :is_equipped, :boolean, default: false
      add :metadata, :map, default: %{}
      add :acquired_at, :utc_datetime

      timestamps()
    end

    create_if_not_exists index(:user_inventory, [:user_id, :item_template_id])

    create_if_not_exists table(:crafting_recipes, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :result_item_id, references(:item_templates, type: :binary_id, on_delete: :delete_all), null: false
      add :result_quantity, :integer, default: 1
      add :success_rate, :float, default: 1.0
      add :required_level, :integer, default: 0
      add :cooldown_seconds, :integer, default: 0

      timestamps()
    end

    create_if_not_exists table(:crafting_ingredients, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :recipe_id, references(:crafting_recipes, type: :binary_id, on_delete: :delete_all), null: false
      add :item_template_id, references(:item_templates, type: :binary_id, on_delete: :delete_all), null: false
      add :quantity, :integer, default: 1

      timestamps()
    end

    # ========================================
    # USER STATS & STREAKS
    # ========================================

    create_if_not_exists table(:user_custom_stats, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :stat_key, :string, null: false
      add :value, :float, default: 0
      add :min_value, :float
      add :max_value, :float

      timestamps()
    end

    create_if_not_exists unique_index(:user_custom_stats, [:user_id, :stat_key])

    create_if_not_exists table(:user_streaks, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :streak_type, :string, null: false
      add :current_count, :integer, default: 0
      add :longest_count, :integer, default: 0
      add :last_activity_date, :date

      timestamps()
    end

    create_if_not_exists unique_index(:user_streaks, [:user_id, :streak_type])

    # ========================================
    # COOLDOWNS
    # ========================================

    create_if_not_exists table(:user_cooldowns, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :action_key, :string, null: false
      add :expires_at, :utc_datetime, null: false

      timestamps()
    end

    create_if_not_exists index(:user_cooldowns, [:user_id, :action_key])

    # ========================================
    # COLLECTIONS
    # ========================================

    create_if_not_exists table(:collection_sets, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :slug, :string, null: false
      add :description, :text
      add :icon, :string
      add :reward_description, :text
      add :reward_points, :integer, default: 0
      add :reward_badge_id, references(:badges, type: :binary_id, on_delete: :nilify_all)

      timestamps()
    end

    create_if_not_exists unique_index(:collection_sets, [:slug])

    create_if_not_exists table(:collection_items, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :collection_set_id, references(:collection_sets, type: :binary_id, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :description, :text
      add :icon, :string
      add :rarity, :string, default: "common"
      add :position, :integer, default: 0

      timestamps()
    end

    create_if_not_exists table(:user_collection_progress, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :collection_item_id, references(:collection_items, type: :binary_id, on_delete: :delete_all), null: false
      add :acquired_at, :utc_datetime

      timestamps()
    end

    create_if_not_exists unique_index(:user_collection_progress, [:user_id, :collection_item_id])

    # ========================================
    # TOURNAMENTS
    # ========================================

    create_if_not_exists table(:tournaments, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :description, :text
      add :format, :string, null: false
      add :status, :string, default: "draft"
      add :max_participants, :integer
      add :registration_deadline, :utc_datetime
      add :started_at, :utc_datetime
      add :completed_at, :utc_datetime
      add :prize_description, :text
      add :created_by_id, references(:users, type: :binary_id, on_delete: :nilify_all), null: false
      add :metadata, :map, default: %{}

      timestamps()
    end

    create_if_not_exists table(:tournament_participants, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :tournament_id, references(:tournaments, type: :binary_id, on_delete: :delete_all), null: false
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :seed, :integer
      add :status, :string, default: "registered"
      add :points, :integer, default: 0

      timestamps()
    end

    create_if_not_exists unique_index(:tournament_participants, [:tournament_id, :user_id])

    create_if_not_exists table(:tournament_matches, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :tournament_id, references(:tournaments, type: :binary_id, on_delete: :delete_all), null: false
      add :round, :integer, null: false
      add :match_number, :integer, null: false
      add :player1_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :player2_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :winner_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :player1_score, :integer, default: 0
      add :player2_score, :integer, default: 0
      add :status, :string, default: "pending"
      add :metadata, :map, default: %{}

      timestamps()
    end

    # ========================================
    # PETS
    # ========================================

    create_if_not_exists table(:pet_templates, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :slug, :string, null: false
      add :description, :text
      add :icon, :string
      add :base_stats, :map, default: %{"hunger" => 100, "happiness" => 100, "health" => 100, "energy" => 100}
      add :evolution_from_id, references(:pet_templates, type: :binary_id, on_delete: :nilify_all)
      add :evolution_threshold, :integer
      add :rarity, :string, default: "common"

      timestamps()
    end

    create_if_not_exists unique_index(:pet_templates, [:slug])

    create_if_not_exists table(:user_pets, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :pet_template_id, references(:pet_templates, type: :binary_id, on_delete: :delete_all), null: false
      add :nickname, :string
      add :stats, :map, default: %{"hunger" => 100, "happiness" => 100, "health" => 100, "energy" => 100}
      add :experience, :integer, default: 0
      add :level, :integer, default: 1
      add :is_active, :boolean, default: true
      add :born_at, :utc_datetime
      add :last_fed_at, :utc_datetime
      add :last_played_at, :utc_datetime
      add :metadata, :map, default: %{}

      timestamps()
    end

    # ========================================
    # QUESTS
    # ========================================

    create_if_not_exists table(:quests, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :slug, :string, null: false
      add :description, :text
      add :quest_type, :string, null: false
      add :is_repeatable, :boolean, default: false
      add :cooldown_hours, :integer
      add :required_level, :integer, default: 0
      add :prerequisite_quest_id, references(:quests, type: :binary_id, on_delete: :nilify_all)
      add :reward_points, :integer, default: 0
      add :reward_items, :map, default: %{}
      add :reward_badge_id, references(:badges, type: :binary_id, on_delete: :nilify_all)
      add :metadata, :map, default: %{}

      timestamps()
    end

    create_if_not_exists unique_index(:quests, [:slug])

    create_if_not_exists table(:quest_steps, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :quest_id, references(:quests, type: :binary_id, on_delete: :delete_all), null: false
      add :step_number, :integer, null: false
      add :description, :text
      add :step_type, :string, null: false
      add :target_value, :integer, default: 1
      add :metadata, :map, default: %{}

      timestamps()
    end

    create_if_not_exists table(:user_quests, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :quest_id, references(:quests, type: :binary_id, on_delete: :delete_all), null: false
      add :status, :string, default: "active"
      add :current_step, :integer, default: 1
      add :progress, :map, default: %{}
      add :started_at, :utc_datetime
      add :completed_at, :utc_datetime

      timestamps()
    end

    create_if_not_exists index(:user_quests, [:user_id, :quest_id])

    # ========================================
    # TICKETS
    # ========================================

    create_if_not_exists table(:tickets, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :title, :string, null: false
      add :description, :text
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :assigned_to_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :status, :string, default: "open"
      add :priority, :string, default: "normal"
      add :category, :string
      add :satisfaction_rating, :integer
      add :resolved_at, :utc_datetime
      add :closed_at, :utc_datetime
      add :metadata, :map, default: %{}

      timestamps()
    end

    create_if_not_exists index(:tickets, [:user_id])
    create_if_not_exists index(:tickets, [:assigned_to_id])

    create_if_not_exists table(:ticket_messages, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :ticket_id, references(:tickets, type: :binary_id, on_delete: :delete_all), null: false
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :body, :text, null: false
      add :is_internal, :boolean, default: false
      add :metadata, :map, default: %{}

      timestamps()
    end

    # ========================================
    # PREDICTIONS & SUGGESTIONS
    # ========================================

    create_if_not_exists table(:predictions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :question, :string, null: false
      add :status, :string, default: "open"
      add :created_by_id, references(:users, type: :binary_id, on_delete: :nilify_all), null: false
      add :outcome_count, :integer, default: 2
      add :total_pool, :bigint, default: 0
      add :currency_id, references(:currencies, type: :binary_id, on_delete: :nilify_all)
      add :resolved_outcome, :string
      add :resolved_at, :utc_datetime
      add :closes_at, :utc_datetime

      timestamps()
    end

    create_if_not_exists table(:prediction_options, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :prediction_id, references(:predictions, type: :binary_id, on_delete: :delete_all), null: false
      add :label, :string, null: false
      add :total_bets, :bigint, default: 0
      add :bet_count, :integer, default: 0

      timestamps()
    end

    create_if_not_exists table(:prediction_bets, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :prediction_id, references(:predictions, type: :binary_id, on_delete: :delete_all), null: false
      add :option_id, references(:prediction_options, type: :binary_id, on_delete: :delete_all), null: false
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :amount, :bigint, null: false
      add :payout, :bigint

      timestamps()
    end

    create_if_not_exists table(:suggestions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :title, :string, null: false
      add :description, :text
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :status, :string, default: "open"
      add :upvotes, :integer, default: 0
      add :downvotes, :integer, default: 0
      add :admin_response, :text
      add :category, :string

      timestamps()
    end

    create_if_not_exists table(:suggestion_votes, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :suggestion_id, references(:suggestions, type: :binary_id, on_delete: :delete_all), null: false
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :vote_type, :string, null: false

      timestamps()
    end

    create_if_not_exists unique_index(:suggestion_votes, [:suggestion_id, :user_id])

    # ========================================
    # ACHIEVEMENTS
    # ========================================

    # achievements table already exists from earlier migration — just add missing columns
    alter table(:achievements) do
      add_if_not_exists :slug, :string
      add_if_not_exists :criteria_metadata, :map, default: %{}
      add_if_not_exists :badge_id, references(:badges, type: :binary_id, on_delete: :nilify_all)
      add_if_not_exists :is_hidden, :boolean, default: false
      add_if_not_exists :position, :integer, default: 0
    end

    # user_achievements already exists — just ensure it has the right columns
    alter table(:user_achievements) do
      add_if_not_exists :unlocked_at, :utc_datetime
    end

    # ========================================
    # VERIFICATION & ONBOARDING
    # ========================================

    create_if_not_exists table(:verification_challenges, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :challenge_type, :string, null: false
      add :challenge_data, :map, default: %{}
      add :status, :string, default: "pending"
      add :expires_at, :utc_datetime
      add :completed_at, :utc_datetime

      timestamps()
    end

    create_if_not_exists table(:onboarding_checklists, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :checklist_data, :map, default: %{}
      add :completed_count, :integer, default: 0
      add :total_count, :integer, default: 0
      add :completed_at, :utc_datetime

      timestamps()
    end

    # ========================================
    # AUTOMOD
    # ========================================

    create_if_not_exists table(:automod_rules, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :description, :text
      add :rule_type, :string, null: false
      add :config, :map, default: %{}
      add :action, :string, null: false
      add :action_duration, :integer
      add :is_enabled, :boolean, default: true
      add :position, :integer, default: 0
      add :exempted_groups, {:array, :string}, default: []

      timestamps()
    end

    # ========================================
    # SEASONS
    # ========================================

    create_if_not_exists table(:seasons, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :description, :text
      add :started_at, :utc_datetime
      add :ends_at, :utc_datetime
      add :status, :string, default: "upcoming"
      add :reward_tiers, :map, default: %{}
      add :metadata, :map, default: %{}

      timestamps()
    end

    # ========================================
    # ALTER EXISTING USERS TABLE
    # ========================================

    alter table(:users) do
      add_if_not_exists :birthday, :date
      add_if_not_exists :trust_level, :integer, default: 0
      add_if_not_exists :infraction_points, :integer, default: 0
    end
  end
end
