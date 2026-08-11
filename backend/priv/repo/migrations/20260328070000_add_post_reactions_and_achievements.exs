defmodule ForgeNexus.Repo.Migrations.AddPostReactionsAndAchievements do
  use Ecto.Migration

  def change do
    # --- Achievements ---
    create table(:achievements, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :description, :string
      add :icon, :string, null: false, default: "🏆"
      add :criteria_type, :string, null: false
      add :criteria_value, :integer, null: false, default: 1

      timestamps()
    end

    create unique_index(:achievements, [:name])

    create table(:user_achievements, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      add :achievement_id, references(:achievements, type: :binary_id, on_delete: :delete_all),
        null: false

      add :earned_at, :utc_datetime, null: false

      timestamps()
    end

    create unique_index(:user_achievements, [:user_id, :achievement_id])
    create index(:user_achievements, [:user_id])
    create index(:user_achievements, [:achievement_id])
  end
end
