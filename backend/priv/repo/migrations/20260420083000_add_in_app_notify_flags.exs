defmodule ForgeNexus.Repo.Migrations.AddInAppNotifyFlags do
  use Ecto.Migration

  def change do
    alter table(:user_preferences) do
      add :notify_replies, :boolean, null: false, default: true
      add :notify_mentions, :boolean, null: false, default: true
      add :notify_reactions, :boolean, null: false, default: true
      add :notify_followers, :boolean, null: false, default: true
      add :notify_badges, :boolean, null: false, default: true
    end
  end
end
