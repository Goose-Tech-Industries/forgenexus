defmodule ForgeNexus.Repo.Migrations.CreateThreadRatings do
  use Ecto.Migration

  def change do
    create table(:thread_ratings, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :rating, :integer, null: false
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :thread_id, references(:threads, type: :binary_id, on_delete: :delete_all), null: false

      timestamps()
    end

    create unique_index(:thread_ratings, [:user_id, :thread_id])
    create index(:thread_ratings, [:thread_id])
  end
end
