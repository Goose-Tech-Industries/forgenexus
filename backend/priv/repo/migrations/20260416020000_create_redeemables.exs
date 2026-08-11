defmodule ForgeNexus.Repo.Migrations.CreateRedeemables do
  use Ecto.Migration

  def change do
    create table(:room_redeemables, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :room_id, references(:voice_rooms, type: :binary_id, on_delete: :delete_all)
      add :created_by_id, references(:users, type: :binary_id, on_delete: :nilify_all)

      add :name, :string, null: false
      add :description, :string
      add :emoji, :string
      add :cost, :integer, null: false
      add :type, :string, null: false
      add :config, :map, default: %{}

      add :cooldown_seconds, :integer, default: 0
      add :max_per_stream, :integer
      add :max_per_user_per_stream, :integer
      add :is_enabled, :boolean, default: true
      add :requires_text, :boolean, default: false
      add :position, :integer, default: 0

      timestamps()
    end

    create index(:room_redeemables, [:room_id])

    create table(:redemptions, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :redeemable_id, references(:room_redeemables, type: :binary_id, on_delete: :delete_all),
        null: false

      add :room_id, references(:voice_rooms, type: :binary_id, on_delete: :delete_all),
        null: false

      add :user_id, references(:users, type: :binary_id, on_delete: :nilify_all), null: false

      add :user_text, :string
      add :cost, :integer, null: false
      add :status, :string, default: "fulfilled"

      timestamps()
    end

    create index(:redemptions, [:room_id, :inserted_at])
    create index(:redemptions, [:user_id])
    create index(:redemptions, [:redeemable_id])
  end
end
