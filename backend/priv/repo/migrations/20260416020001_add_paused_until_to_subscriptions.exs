defmodule ForgeNexus.Repo.Migrations.AddPausedUntilToSubscriptions do
  use Ecto.Migration

  def change do
    alter table(:user_subscriptions) do
      add :paused_until, :utc_datetime
    end
  end
end
