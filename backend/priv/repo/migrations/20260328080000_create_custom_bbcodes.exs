defmodule ForgeNexus.Repo.Migrations.CreateCustomBbcodes do
  use Ecto.Migration

  def change do
    create table(:custom_bbcodes, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :tag_name, :string, null: false
      add :replacement_html, :text, null: false
      add :description, :string, default: ""
      add :is_active, :boolean, default: true

      timestamps()
    end

    create unique_index(:custom_bbcodes, [:tag_name])
  end
end
