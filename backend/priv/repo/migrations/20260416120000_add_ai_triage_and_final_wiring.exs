defmodule ForgeNexus.Repo.Migrations.AddAiTriageAndFinalWiring do
  use Ecto.Migration

  def change do
    # AI triage fields on reports
    alter table(:reports) do
      add_if_not_exists :ai_severity, :string
      add_if_not_exists :ai_category, :string
      add_if_not_exists :ai_confidence, :float
      add_if_not_exists :ai_reason, :string
    end

    # Live translation cache
    create table(:voice_translations, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :room_id, references(:voice_rooms, type: :binary_id, on_delete: :delete_all)
      add :user_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :source_text, :text, null: false
      add :source_language, :string
      add :target_language, :string, null: false
      add :translated_text, :text, null: false
      add :model, :string

      timestamps()
    end

    create index(:voice_translations, [:room_id, :inserted_at])

    # Plugin marketplace — purchases tracking
    create table(:plugin_purchases, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :plugin_id, references(:js_plugins, type: :binary_id, on_delete: :nilify_all)
      add :user_id, references(:users, type: :binary_id, on_delete: :nilify_all), null: false
      add :community_id, references(:communities, type: :binary_id, on_delete: :nilify_all)
      add :amount_cents, :integer, null: false
      add :platform_fee_cents, :integer, null: false
      add :developer_amount_cents, :integer, null: false
      add :stripe_payment_intent_id, :string

      timestamps()
    end

    create index(:plugin_purchases, [:user_id])
    create index(:plugin_purchases, [:plugin_id])

    # Template purchases
    create table(:template_purchases, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :template_id, references(:community_templates, type: :binary_id, on_delete: :nilify_all)
      add :community_id, references(:communities, type: :binary_id, on_delete: :delete_all)
      add :user_id, references(:users, type: :binary_id, on_delete: :nilify_all), null: false
      add :amount_cents, :integer, null: false

      timestamps()
    end

    create index(:template_purchases, [:template_id])
  end
end
