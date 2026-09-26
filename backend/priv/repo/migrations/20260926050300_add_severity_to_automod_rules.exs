defmodule ForgeNexus.Repo.Migrations.AddSeverityToAutomodRules do
  use Ecto.Migration

  def change do
    alter table(:automod_rules) do
      add_if_not_exists :severity, :integer, default: 1
    end
  end
end
