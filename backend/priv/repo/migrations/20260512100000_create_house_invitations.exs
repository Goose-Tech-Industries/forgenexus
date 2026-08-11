defmodule ForgeNexus.Repo.Migrations.CreateHouseInvitations do
  use Ecto.Migration

  def change do
    # Pending invitations to a House (multi-creator collective). The house
    # itself is a Community with plan="houses"; this table holds the
    # outstanding tokenized invites the founder can hand to each creator.
    create table(:house_invitations, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :community_id, references(:communities, type: :binary_id, on_delete: :delete_all),
        null: false

      add :inviter_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :email, :string, null: false
      add :token_hash, :string, null: false
      add :role, :string, default: "creator", null: false
      add :accepted_at, :utc_datetime
      add :accepted_by_user_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :expires_at, :utc_datetime, null: false

      timestamps()
    end

    create unique_index(:house_invitations, [:token_hash])
    create index(:house_invitations, [:community_id])
    create index(:house_invitations, [:email])
  end
end
