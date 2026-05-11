defmodule ForgeNexus.Repo.Migrations.AddForumRulesAndThreadThumbnails do
  use Ecto.Migration

  def change do
    alter table(:forums) do
      add :rules, :text
    end

    alter table(:threads) do
      add :thumbnail_url, :string
    end
  end
end
