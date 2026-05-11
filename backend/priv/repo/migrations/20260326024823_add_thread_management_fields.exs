defmodule ForgeNexus.Repo.Migrations.AddThreadManagementFields do
  use Ecto.Migration

  def change do
    alter table(:threads) do
      add :moved_from_forum_id, references(:forums, type: :binary_id, on_delete: :nilify_all)
      add :merged_into_id, references(:threads, type: :binary_id, on_delete: :nilify_all)
    end

    alter table(:posts) do
      add :merged_from_thread_id, references(:threads, type: :binary_id, on_delete: :nilify_all)
    end

    create index(:threads, [:merged_into_id])
  end
end
