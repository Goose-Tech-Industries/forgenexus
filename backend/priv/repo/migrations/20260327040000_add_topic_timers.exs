defmodule ForgeNexus.Repo.Migrations.AddTopicTimers do
  use Ecto.Migration

  def change do
    alter table(:threads) do
      add :auto_close_at, :utc_datetime
      add :auto_delete_at, :utc_datetime
    end
  end
end
