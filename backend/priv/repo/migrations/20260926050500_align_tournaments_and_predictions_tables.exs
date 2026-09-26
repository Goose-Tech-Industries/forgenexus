defmodule ForgeNexus.Repo.Migrations.AlignTournamentsAndPredictionsTables do
  use Ecto.Migration

  def up do
    alter table(:tournaments) do
      add_if_not_exists :prize_pool, :map, default: %{}
      add_if_not_exists :starts_at, :utc_datetime
      add_if_not_exists :ends_at, :utc_datetime
      add_if_not_exists :rules, :text
    end

    alter table(:tournament_participants) do
      add_if_not_exists :wins, :integer, default: 0
      add_if_not_exists :losses, :integer, default: 0
      add_if_not_exists :is_eliminated, :boolean, default: false
    end

    alter table(:tournament_matches) do
      modify :match_number, :integer, null: true
      add_if_not_exists :position, :integer
      add_if_not_exists :scores, :map, default: %{}
    end

    alter table(:predictions) do
      modify :question, :string, null: true
      add_if_not_exists :title, :string
      add_if_not_exists :description, :text
      add_if_not_exists :winning_option, :string
    end

    alter table(:prediction_options) do
      add_if_not_exists :total_amount, :bigint, default: 0
    end

    alter table(:suggestions) do
      add_if_not_exists :staff_response, :text
    end

    alter table(:suggestion_votes) do
      modify :vote_type, :string, null: true
      add_if_not_exists :direction, :string
    end
  end

  def down do
    alter table(:suggestion_votes) do
      remove_if_exists :direction, :string
      modify :vote_type, :string, null: false
    end

    alter table(:suggestions) do
      remove_if_exists :staff_response, :text
    end

    alter table(:prediction_options) do
      remove_if_exists :total_amount, :bigint
    end

    alter table(:predictions) do
      remove_if_exists :winning_option, :string
      remove_if_exists :description, :text
      remove_if_exists :title, :string
      modify :question, :string, null: false
    end

    alter table(:tournament_matches) do
      remove_if_exists :scores, :map
      remove_if_exists :position, :integer
      modify :match_number, :integer, null: false
    end

    alter table(:tournament_participants) do
      remove_if_exists :is_eliminated, :boolean
      remove_if_exists :losses, :integer
      remove_if_exists :wins, :integer
    end

    alter table(:tournaments) do
      remove_if_exists :rules, :text
      remove_if_exists :ends_at, :utc_datetime
      remove_if_exists :starts_at, :utc_datetime
      remove_if_exists :prize_pool, :map
    end
  end
end
