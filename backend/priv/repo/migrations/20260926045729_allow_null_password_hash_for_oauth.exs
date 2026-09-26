defmodule ForgeNexus.Repo.Migrations.AllowNullPasswordHashForOauth do
  use Ecto.Migration

  def up do
    alter table(:users) do
      modify :password_hash, :string, null: true
    end
  end

  def down do
    alter table(:users) do
      modify :password_hash, :string, null: false
    end
  end
end
