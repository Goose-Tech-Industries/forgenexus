defmodule ForgeNexus.Repo.Migrations.AddDmReactionsAndDeleted do
  use Ecto.Migration

  def change do
    alter table(:messages) do
      add_if_not_exists :is_deleted, :boolean, default: false
      add_if_not_exists :reactions, :map, default: %{}
    end
  end
end
