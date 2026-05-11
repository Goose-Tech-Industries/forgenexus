defmodule ForgeNexus.Repo.Migrations.OauthEmailSupport do
  @moduledoc """
  Support proper OAuth sign-in:

    * Allow `users.email` to be NULL (OAuth providers may not return one).
    * Add `users.email_unverified` boolean flag so the UI can prompt the user
      to supply / confirm an email later.
  """
  use Ecto.Migration

  def up do
    alter table(:users) do
      modify :email, :string, null: true
      add :email_unverified, :boolean, default: false, null: false
    end
  end

  def down do
    alter table(:users) do
      remove :email_unverified
    end

    execute "UPDATE users SET email = id || '@unknown.local' WHERE email IS NULL"

    alter table(:users) do
      modify :email, :string, null: false
    end
  end
end
