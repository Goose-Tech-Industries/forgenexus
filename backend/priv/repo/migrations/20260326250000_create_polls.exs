defmodule ForgeNexus.Repo.Migrations.CreatePolls do
  use Ecto.Migration

  def change do
    create_if_not_exists table(:polls, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :question, :string, null: false
      add :thread_id, references(:threads, type: :binary_id, on_delete: :delete_all), null: false

      add :created_by_id, references(:users, type: :binary_id, on_delete: :nilify_all),
        null: false

      add :is_multiple_choice, :boolean, default: false
      add :max_choices, :integer, default: 1
      add :is_anonymous, :boolean, default: false
      add :hide_results_until_voted, :boolean, default: false
      add :is_closed, :boolean, default: false
      add :closes_at, :utc_datetime
      add :total_votes, :integer, default: 0

      timestamps()
    end

    create_if_not_exists unique_index(:polls, [:thread_id])

    create_if_not_exists table(:poll_options, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :poll_id, references(:polls, type: :binary_id, on_delete: :delete_all), null: false
      add :text, :string, null: false
      add :position, :integer, default: 0
      add :vote_count, :integer, default: 0

      timestamps()
    end

    create_if_not_exists index(:poll_options, [:poll_id])

    create_if_not_exists table(:poll_votes, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :poll_id, references(:polls, type: :binary_id, on_delete: :delete_all), null: false

      add :option_id, references(:poll_options, type: :binary_id, on_delete: :delete_all),
        null: false

      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      timestamps()
    end

    create_if_not_exists index(:poll_votes, [:poll_id, :user_id])
    create unique_index(:poll_votes, [:option_id, :user_id])
  end
end
