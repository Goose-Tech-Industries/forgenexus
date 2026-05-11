defmodule ForgeNexus.Repo.Migrations.AddScheduledAndDescriptionToVoiceRooms do
  use Ecto.Migration

  def change do
    alter table(:voice_rooms) do
      add :scheduled_at, :utc_datetime
      add :description, :text
    end

    create index(:voice_rooms, [:scheduled_at],
      where: "scheduled_at IS NOT NULL",
      name: :voice_rooms_scheduled_at_index
    )
  end
end
