defmodule ForgeNexus.Repo.Migrations.AddStageMetricsToCallLogs do
  use Ecto.Migration

  def change do
    alter table(:voice_call_logs) do
      add :peak_audience, :integer, default: 0, null: false
      add :peak_speakers, :integer, default: 0, null: false
      add :total_hand_raises, :integer, default: 0, null: false
      add :total_promotions, :integer, default: 0, null: false
      add :total_demotions, :integer, default: 0, null: false
      add :host_user_id, :binary_id
    end
  end
end
