defmodule ForgeNexus.Repo.Migrations.AddRatingAndEscalationToTickets do
  use Ecto.Migration

  def change do
    alter table(:tickets) do
      add_if_not_exists :rating, :integer
      add_if_not_exists :escalation_reason, :text
    end
  end
end
