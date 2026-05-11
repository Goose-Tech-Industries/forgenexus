defmodule ForgeNexus.Repo.Migrations.AddTournamentEntryFees do
  use Ecto.Migration

  def change do
    alter table(:tournaments) do
      add_if_not_exists :entry_fee_points, :integer, default: 0
      add_if_not_exists :entry_fee_cents, :integer, default: 0
    end
  end
end
