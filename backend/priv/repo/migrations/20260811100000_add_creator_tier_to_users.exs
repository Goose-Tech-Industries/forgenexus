defmodule ForgeNexus.Repo.Migrations.AddCreatorTierToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :creator_tier, :string, default: "basic", null: false
    end
  end
end
