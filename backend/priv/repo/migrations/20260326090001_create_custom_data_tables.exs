defmodule ForgeNexus.Repo.Migrations.CreateCustomDataTables do
  use Ecto.Migration

  def change do
    create table(:custom_data_tables, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :slug, :string, null: false
      add :description, :text
      add :scope, :string, null: false, default: "global"
      add :max_rows, :integer, default: 10000
      add :created_by_id, references(:users, type: :binary_id, on_delete: :nilify_all), null: false

      timestamps()
    end

    create unique_index(:custom_data_tables, [:slug])
    create index(:custom_data_tables, [:scope])
    create index(:custom_data_tables, [:created_by_id])

    create table(:custom_data_columns, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :table_id, references(:custom_data_tables, type: :binary_id, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :slug, :string, null: false
      add :data_type, :string, null: false
      add :default_value, :string
      add :is_required, :boolean, default: false
      add :is_indexed, :boolean, default: false
      add :is_unique, :boolean, default: false
      add :position, :integer, default: 0
      add :validations, :map, default: %{}

      timestamps()
    end

    create index(:custom_data_columns, [:table_id])
    create unique_index(:custom_data_columns, [:table_id, :slug])

    create table(:custom_data_rows, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :table_id, references(:custom_data_tables, type: :binary_id, on_delete: :delete_all), null: false
      add :scope_id, :binary_id
      add :data, :map, null: false, default: %{}
      add :version, :integer, default: 1

      timestamps()
    end

    create index(:custom_data_rows, [:table_id])
    create index(:custom_data_rows, [:table_id, :scope_id])
  end
end
