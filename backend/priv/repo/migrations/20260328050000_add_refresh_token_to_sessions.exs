defmodule ForgeNexus.Repo.Migrations.AddRefreshTokenToSessions do
  use Ecto.Migration

  def change do
    alter table(:login_sessions) do
      add :refresh_token, :string
    end

    create unique_index(:login_sessions, [:refresh_token])
  end
end
