defmodule ForgeNexus.Repo.Migrations.AddSortOrderToAutomodRules do
  use Ecto.Migration

  def change do
    alter table(:automod_rules) do
      add_if_not_exists :sort_order, :integer, default: 0
    end
  end
end
