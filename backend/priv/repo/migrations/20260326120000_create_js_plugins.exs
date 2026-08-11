defmodule ForgeNexus.Repo.Migrations.CreateJsPlugins do
  use Ecto.Migration

  def change do
    create table(:js_plugins, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :slug, :string, null: false
      add :description, :text
      add :version, :string, default: "1.0.0"
      add :status, :string, null: false, default: "draft"
      add :code, :text, null: false, default: ""
      add :manifest, :map, null: false, default: %{}
      add :settings, :map, default: %{}
      add :error_message, :text
      add :last_executed_at, :utc_datetime
      add :execution_count, :integer, default: 0
      add :created_by_id, references(:users, type: :binary_id, on_delete: :nilify_all)

      timestamps()
    end

    create unique_index(:js_plugins, [:slug])
    create index(:js_plugins, [:status])
    create index(:js_plugins, [:created_by_id])

    create table(:js_plugin_executions, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :js_plugin_id, references(:js_plugins, type: :binary_id, on_delete: :delete_all),
        null: false

      add :status, :string, null: false, default: "running"
      add :trigger_type, :string
      add :trigger_data, :map, default: %{}
      add :result, :map, default: %{}
      add :logs, {:array, :string}, default: []
      add :started_at, :utc_datetime, null: false
      add :finished_at, :utc_datetime
      add :duration_ms, :integer
      add :triggered_by_id, :binary_id

      timestamps()
    end

    create index(:js_plugin_executions, [:js_plugin_id])
    create index(:js_plugin_executions, [:js_plugin_id, :status])
    create index(:js_plugin_executions, [:js_plugin_id, :inserted_at])
    create index(:js_plugin_executions, [:status])

    create table(:js_plugin_rate_limits, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :js_plugin_id, references(:js_plugins, type: :binary_id, on_delete: :delete_all),
        null: false

      add :window_start, :utc_datetime, null: false
      add :window_seconds, :integer, null: false, default: 3600
      add :execution_count, :integer, null: false, default: 0

      timestamps()
    end

    create unique_index(:js_plugin_rate_limits, [:js_plugin_id, :window_start])
  end
end
