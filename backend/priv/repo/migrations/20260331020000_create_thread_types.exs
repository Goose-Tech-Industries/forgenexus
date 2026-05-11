defmodule ForgeNexus.Repo.Migrations.CreateThreadTypes do
  use Ecto.Migration

  def change do
    # 1. Thread Types — available thread types
    create table(:thread_types, primary_key: false) do
      add :id, :binary_id, primary_key: true, autogenerate: true
      add :name, :string, null: false
      add :slug, :string, null: false
      add :label, :string, null: false
      add :icon, :string
      add :description, :text
      add :config, :map, default: %{}
      add :is_builtin, :boolean, default: false
      add :is_active, :boolean, default: true
      add :position, :integer, default: 0
      add :created_by_id, references(:users, type: :binary_id, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create unique_index(:thread_types, [:slug])
    create index(:thread_types, [:created_by_id])

    # 2. Thread Answers — for Q&A threads
    create table(:thread_answers, primary_key: false) do
      add :id, :binary_id, primary_key: true, autogenerate: true
      add :thread_id, references(:threads, type: :binary_id, on_delete: :delete_all)
      add :post_id, references(:posts, type: :binary_id, on_delete: :delete_all)
      add :is_accepted, :boolean, default: false
      add :vote_count, :integer, default: 0
      add :accepted_by_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :accepted_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:thread_answers, [:thread_id, :post_id])
    create index(:thread_answers, [:thread_id])
    create index(:thread_answers, [:post_id])
    create index(:thread_answers, [:accepted_by_id])

    # 3. Answer Votes — votes on Q&A answers
    create table(:answer_votes, primary_key: false) do
      add :id, :binary_id, primary_key: true, autogenerate: true
      add :thread_answer_id, references(:thread_answers, type: :binary_id, on_delete: :delete_all)
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all)
      add :value, :integer, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:answer_votes, [:thread_answer_id, :user_id])
    create index(:answer_votes, [:thread_answer_id])
    create index(:answer_votes, [:user_id])

    # 4. Debate Positions — for debate threads
    create table(:debate_positions, primary_key: false) do
      add :id, :binary_id, primary_key: true, autogenerate: true
      add :thread_id, references(:threads, type: :binary_id, on_delete: :delete_all)
      add :post_id, references(:posts, type: :binary_id, on_delete: :delete_all)
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all)
      add :side, :string, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:debate_positions, [:thread_id, :post_id])
    create index(:debate_positions, [:thread_id])
    create index(:debate_positions, [:post_id])
    create index(:debate_positions, [:user_id])

    # 5. AMA Sessions — for AMA threads
    create table(:ama_sessions, primary_key: false) do
      add :id, :binary_id, primary_key: true, autogenerate: true
      add :thread_id, references(:threads, type: :binary_id, on_delete: :delete_all)
      add :host_id, references(:users, type: :binary_id, on_delete: :delete_all)
      add :title, :string
      add :description, :text
      add :scheduled_start, :utc_datetime
      add :scheduled_end, :utc_datetime
      add :status, :string, default: "upcoming"

      timestamps(type: :utc_datetime)
    end

    create unique_index(:ama_sessions, [:thread_id])
    create index(:ama_sessions, [:host_id])

    # 6. Marketplace Listings — for marketplace threads
    create table(:marketplace_listings, primary_key: false) do
      add :id, :binary_id, primary_key: true, autogenerate: true
      add :thread_id, references(:threads, type: :binary_id, on_delete: :delete_all)
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all)
      add :price, :decimal, precision: 10, scale: 2
      add :currency, :string, default: "USD"
      add :condition, :string
      add :status, :string, default: "available"
      add :location, :string
      add :shipping_info, :text

      timestamps(type: :utc_datetime)
    end

    create unique_index(:marketplace_listings, [:thread_id])
    create index(:marketplace_listings, [:user_id])

    # 7. Wiki Edits — for wiki-style collaborative threads
    create table(:wiki_edits, primary_key: false) do
      add :id, :binary_id, primary_key: true, autogenerate: true
      add :thread_id, references(:threads, type: :binary_id, on_delete: :delete_all)
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all)
      add :body, :text, null: false
      add :body_html, :text
      add :edit_summary, :string
      add :revision_number, :integer, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:wiki_edits, [:thread_id, :revision_number])
    create index(:wiki_edits, [:thread_id])
    create index(:wiki_edits, [:user_id])

    # ALTER threads table — add thread_type_id
    alter table(:threads) do
      add :thread_type_id, references(:thread_types, type: :binary_id, on_delete: :nilify_all)
    end

    create index(:threads, [:thread_type_id])
  end
end
