defmodule ForgeNexus.Repo.Migrations.AddRevenueShareFieldsToMoneyTips do
  use Ecto.Migration

  def change do
    alter table(:money_tips) do
      add :stripe_fee_cents, :integer, default: 0
      add :community_kickback_cents, :integer, default: 0
      add :community_owner_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :community_plan, :string
      add :platform_net_cents, :integer, default: 0
    end
  end
end
