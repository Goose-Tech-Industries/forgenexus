defmodule ForgeNexus.Repo.Migrations.CreateAiInfrastructure do
  use Ecto.Migration

  def change do
    # ── AI Providers ──────────────────────────────────────────────────────
    create table(:ai_providers, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :display_name, :string
      add :api_key_encrypted, :binary
      add :base_url, :string
      add :default_model, :string
      add :is_active, :boolean, default: false
      add :priority, :integer, default: 0
      add :max_tokens_per_request, :integer, default: 4096
      add :config, :map, default: %{}

      timestamps()
    end

    create index(:ai_providers, [:name])
    create index(:ai_providers, [:is_active])

    # ── AI Usage Logs ─────────────────────────────────────────────────────
    create table(:ai_usage_logs, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :provider_id, references(:ai_providers, type: :binary_id, on_delete: :nothing)
      add :feature, :string, null: false
      add :input_tokens, :integer, default: 0
      add :output_tokens, :integer, default: 0
      add :cost_cents, :integer, default: 0
      add :latency_ms, :integer
      add :user_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :metadata, :map, default: %{}
      add :error, :text

      timestamps()
    end

    create index(:ai_usage_logs, [:provider_id])
    create index(:ai_usage_logs, [:user_id])
    create index(:ai_usage_logs, [:feature])
    create index(:ai_usage_logs, [:inserted_at])

    # ── AI Feature Settings ───────────────────────────────────────────────
    create table(:ai_feature_settings, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :feature, :string, null: false
      add :enabled, :boolean, default: false
      add :provider_id, references(:ai_providers, type: :binary_id, on_delete: :nilify_all)
      add :config, :map, default: %{}

      timestamps()
    end

    create unique_index(:ai_feature_settings, [:feature])
    create index(:ai_feature_settings, [:provider_id])

    # ── AI Moderation Analyses ────────────────────────────────────────────
    create table(:ai_moderation_analyses, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :report_id, references(:reports, type: :binary_id, on_delete: :delete_all)
      add :post_id, references(:posts, type: :binary_id, on_delete: :nilify_all)
      add :thread_id, references(:threads, type: :binary_id, on_delete: :nilify_all)
      add :suggested_action, :string
      add :confidence, :float
      add :reasoning, :text
      add :context_summary, :text
      add :mod_decision, :string
      add :mod_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :was_accepted, :boolean
      add :provider_id, references(:ai_providers, type: :binary_id, on_delete: :nothing)

      timestamps()
    end

    create index(:ai_moderation_analyses, [:report_id])
    create index(:ai_moderation_analyses, [:post_id])
    create index(:ai_moderation_analyses, [:thread_id])
    create index(:ai_moderation_analyses, [:mod_id])
    create index(:ai_moderation_analyses, [:provider_id])

    # ── Thread Summaries ──────────────────────────────────────────────────
    create table(:thread_summaries, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :thread_id, references(:threads, type: :binary_id, on_delete: :delete_all)
      add :summary, :text
      add :key_points, {:array, :string}, default: []
      add :participant_count, :integer
      add :post_count_at_generation, :integer
      add :last_generated_at, :utc_datetime
      add :provider_id, references(:ai_providers, type: :binary_id, on_delete: :nothing)

      timestamps()
    end

    create unique_index(:thread_summaries, [:thread_id])
    create index(:thread_summaries, [:provider_id])

    # ── AI Tag Suggestions ────────────────────────────────────────────────
    create table(:ai_tag_suggestions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :thread_id, references(:threads, type: :binary_id, on_delete: :delete_all)
      add :suggested_tags, {:array, :string}, default: []
      add :suggested_prefix, :string
      add :suggested_forum_id, references(:forums, type: :binary_id, on_delete: :nilify_all)
      add :content_type, :string
      add :confidence, :float
      add :was_applied, :boolean, default: false
      add :reviewed_by_id, references(:users, type: :binary_id, on_delete: :nilify_all)

      timestamps()
    end

    create index(:ai_tag_suggestions, [:thread_id])
    create index(:ai_tag_suggestions, [:suggested_forum_id])
    create index(:ai_tag_suggestions, [:reviewed_by_id])

    # ── Post Sentiments ───────────────────────────────────────────────────
    create table(:post_sentiments, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :post_id, references(:posts, type: :binary_id, on_delete: :delete_all)
      add :thread_id, references(:threads, type: :binary_id, on_delete: :delete_all)
      add :sentiment, :float
      add :emotion_tags, {:array, :string}, default: []

      timestamps()
    end

    create unique_index(:post_sentiments, [:post_id])
    create index(:post_sentiments, [:thread_id])

    # ── Community Sentiment Daily ─────────────────────────────────────────
    create table(:community_sentiment_daily, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :date, :date
      add :avg_sentiment, :float
      add :total_posts_analyzed, :integer, default: 0
      add :heated_thread_count, :integer, default: 0
      add :top_emotions, :map, default: %{}

      timestamps()
    end

    create unique_index(:community_sentiment_daily, [:date])

    # ── Post Translations ─────────────────────────────────────────────────
    create table(:post_translations, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :post_id, references(:posts, type: :binary_id, on_delete: :delete_all)
      add :source_language, :string, default: "en"
      add :target_language, :string, null: false
      add :translated_body, :text, null: false
      add :provider_id, references(:ai_providers, type: :binary_id, on_delete: :nothing)

      timestamps()
    end

    create unique_index(:post_translations, [:post_id, :target_language])
    create index(:post_translations, [:provider_id])

    # ── ALTER existing tables ─────────────────────────────────────────────
    alter table(:forums) do
      add :ai_summary_enabled, :boolean, default: true
    end

    alter table(:user_preferences) do
      add :ai_content_assist_enabled, :boolean, default: true
      add :preferred_language, :string, default: "en"
    end
  end
end
