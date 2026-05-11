defmodule ForgeNexus.Repo.Migrations.AddCurrencyIconAndActive do
  use Ecto.Migration

  def change do
    alter table(:currencies) do
      add_if_not_exists :icon, :string
      add_if_not_exists :is_active, :boolean, default: true, null: false
    end
  end
end
