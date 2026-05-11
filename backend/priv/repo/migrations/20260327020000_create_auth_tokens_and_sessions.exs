defmodule ForgeNexus.Repo.Migrations.CreateAuthTokensAndSessions do
  use Ecto.Migration

  def change do
    # Auth tokens for email verification, password reset, email change
    create table(:auth_tokens, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :token, :string, null: false
      add :type, :string, null: false  # "email_verify", "password_reset", "email_change"
      add :email, :string  # for email_change: the new email
      add :used_at, :utc_datetime
      add :expires_at, :utc_datetime, null: false
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      timestamps()
    end

    create unique_index(:auth_tokens, [:token])
    create index(:auth_tokens, [:user_id])
    create index(:auth_tokens, [:type, :user_id])

    # Login sessions (active device tracking)
    create table(:login_sessions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :token_jti, :string, null: false  # JWT ID for revocation
      add :ip_address, :string
      add :user_agent, :string
      add :device_name, :string  # parsed from user_agent
      add :last_active_at, :utc_datetime
      add :revoked_at, :utc_datetime
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      timestamps()
    end

    create unique_index(:login_sessions, [:token_jti])
    create index(:login_sessions, [:user_id])

    # Login attempts (rate limiting + history)
    create table(:login_attempts, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :email, :string, null: false
      add :ip_address, :string
      add :success, :boolean, default: false
      add :user_id, references(:users, type: :binary_id, on_delete: :nilify_all)

      timestamps(updated_at: false)
    end

    create index(:login_attempts, [:email])
    create index(:login_attempts, [:ip_address])

    # Add email_verified fields to users
    alter table(:users) do
      add :email_verified_at, :utc_datetime
      add :deactivated_at, :utc_datetime
      add :deactivation_reason, :string
    end
  end
end
