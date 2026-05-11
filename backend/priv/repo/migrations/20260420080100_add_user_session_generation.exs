defmodule ForgeNexus.Repo.Migrations.AddUserSessionGeneration do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :session_generation, :integer, null: false, default: 0
    end
  end
end
