defmodule ForgeNexus.Repo.Migrations.CreateCustomEmojis do
  use Ecto.Migration

  def change do
    create table(:custom_emojis, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :shortcode, :string, null: false
      add :image_url, :string, null: false
      add :category, :string, default: "custom"
      add :is_animated, :boolean, default: false
      add :is_active, :boolean, default: true
      add :created_by_id, references(:users, type: :binary_id, on_delete: :nilify_all)

      timestamps()
    end

    create unique_index(:custom_emojis, [:shortcode])
    create index(:custom_emojis, [:category])
  end
end
