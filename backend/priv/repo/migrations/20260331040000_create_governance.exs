defmodule ForgeNexus.Repo.Migrations.CreateGovernance do
  use Ecto.Migration

  def change do
    # Proposals
    create table(:proposals, primary_key: false) do
      add :id, :binary_id, primary_key: true, autogenerate: true
      add :title, :string, null: false
      add :body, :text, null: false
      add :body_html, :text
      add :type, :string, null: false
      add :status, :string, default: "discussion"
      add :author_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :discussion_ends_at, :utc_datetime
      add :voting_starts_at, :utc_datetime
      add :voting_ends_at, :utc_datetime
      add :threshold_type, :string, default: "simple_majority"
      add :min_participation, :integer, default: 0
      add :is_binding, :boolean, default: false
      add :yes_count, :integer, default: 0
      add :no_count, :integer, default: 0
      add :abstain_count, :integer, default: 0
      add :result_summary, :text

      timestamps(type: :utc_datetime)
    end

    create index(:proposals, [:author_id])
    create index(:proposals, [:status])
    create index(:proposals, [:type])
    create index(:proposals, [:voting_ends_at])

    # Proposal Votes
    create table(:proposal_votes, primary_key: false) do
      add :id, :binary_id, primary_key: true, autogenerate: true
      add :proposal_id, references(:proposals, type: :binary_id, on_delete: :delete_all)
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all)
      add :vote, :string, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:proposal_votes, [:proposal_id, :user_id])
    create index(:proposal_votes, [:user_id])

    # Proposal Comments
    create table(:proposal_comments, primary_key: false) do
      add :id, :binary_id, primary_key: true, autogenerate: true
      add :proposal_id, references(:proposals, type: :binary_id, on_delete: :delete_all)
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all)
      add :body, :text, null: false
      add :body_html, :text

      timestamps(type: :utc_datetime)
    end

    create index(:proposal_comments, [:proposal_id])
    create index(:proposal_comments, [:user_id])

    # Elections
    create table(:elections, primary_key: false) do
      add :id, :binary_id, primary_key: true, autogenerate: true
      add :proposal_id, references(:proposals, type: :binary_id, on_delete: :delete_all)
      add :position, :string, null: false
      add :max_winners, :integer, default: 1
      add :nomination_ends_at, :utc_datetime
      add :status, :string, default: "nominations"

      timestamps(type: :utc_datetime)
    end

    create index(:elections, [:proposal_id])
    create index(:elections, [:status])

    # Election Candidates
    create table(:election_candidates, primary_key: false) do
      add :id, :binary_id, primary_key: true, autogenerate: true
      add :election_id, references(:elections, type: :binary_id, on_delete: :delete_all)
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all)
      add :platform, :text
      add :nominated_by_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :is_accepted, :boolean, default: false
      add :vote_count, :integer, default: 0

      timestamps(type: :utc_datetime)
    end

    create unique_index(:election_candidates, [:election_id, :user_id])
    create index(:election_candidates, [:user_id])
    create index(:election_candidates, [:nominated_by_id])
  end
end
