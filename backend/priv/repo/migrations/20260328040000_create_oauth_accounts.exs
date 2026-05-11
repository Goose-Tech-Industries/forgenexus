defmodule ForgeNexus.Repo.Migrations.CreateOauthAccounts do
  use Ecto.Migration

  def change do
    create table(:oauth_accounts, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :provider, :string, null: false
      add :provider_uid, :string, null: false
      add :provider_email, :string
      add :provider_name, :string
      add :provider_avatar, :string
      add :access_token, :text
      add :refresh_token, :text
      add :user_id, references(:users, on_delete: :delete_all, type: :binary_id), null: false

      timestamps()
    end

    create unique_index(:oauth_accounts, [:provider, :provider_uid])
    create unique_index(:oauth_accounts, [:provider, :user_id])
    create index(:oauth_accounts, [:user_id])
  end
end
