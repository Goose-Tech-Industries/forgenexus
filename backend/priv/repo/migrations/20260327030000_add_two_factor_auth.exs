defmodule ForgeNexus.Repo.Migrations.AddTwoFactorAuth do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :totp_secret, :string
      add :totp_enabled, :boolean, default: false
      add :totp_backup_codes, {:array, :string}, default: []
    end
  end
end
