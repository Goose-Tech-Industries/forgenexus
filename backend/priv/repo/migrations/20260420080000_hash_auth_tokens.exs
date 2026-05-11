defmodule ForgeNexus.Repo.Migrations.HashAuthTokens do
  use Ecto.Migration

  def up do
    # Drop all existing rows — their plaintext is the security problem we're fixing.
    # Any pending verify/reset/change links become invalid; affected users can re-request.
    execute "DELETE FROM auth_tokens"

    drop unique_index(:auth_tokens, [:token])

    alter table(:auth_tokens) do
      remove :token
      add :token_hash, :string, null: false
    end

    create unique_index(:auth_tokens, [:token_hash])
  end

  def down do
    drop unique_index(:auth_tokens, [:token_hash])

    alter table(:auth_tokens) do
      remove :token_hash
      add :token, :string, null: false
    end

    create unique_index(:auth_tokens, [:token])
  end
end
