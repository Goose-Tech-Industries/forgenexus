defmodule ForgeNexus.Repo.Migrations.ExtendLoginAttemptsToEvents do
  use Ecto.Migration

  def change do
    alter table(:login_attempts) do
      add :user_agent, :string, size: 512
      add :failure_reason, :string
      add :occurred_at, :utc_datetime_usec
    end

    create index(:login_attempts, [:user_id, :inserted_at])
    create index(:login_attempts, [:success, :inserted_at])
  end
end
