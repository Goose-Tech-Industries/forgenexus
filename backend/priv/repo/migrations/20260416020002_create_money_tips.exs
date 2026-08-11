defmodule ForgeNexus.Repo.Migrations.CreateMoneyTips do
  use Ecto.Migration

  def change do
    create table(:money_tips, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :sender_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :recipient_id, references(:users, type: :binary_id, on_delete: :nilify_all), null: false
      add :room_id, references(:voice_rooms, type: :binary_id, on_delete: :nilify_all)

      add :amount_cents, :integer, null: false
      add :currency, :string, default: "usd", null: false
      add :message, :string
      add :is_anonymous, :boolean, default: false

      add :platform_fee_cents, :integer, null: false
      add :creator_amount_cents, :integer, null: false
      add :creator_tier, :string

      add :stripe_payment_intent_id, :string
      add :stripe_transfer_id, :string
      add :status, :string, default: "pending", null: false

      timestamps()
    end

    create index(:money_tips, [:recipient_id, :inserted_at])
    create index(:money_tips, [:sender_id])
    create index(:money_tips, [:room_id])

    create index(:money_tips, [:stripe_payment_intent_id],
             unique: true,
             where: "stripe_payment_intent_id IS NOT NULL"
           )
  end
end
