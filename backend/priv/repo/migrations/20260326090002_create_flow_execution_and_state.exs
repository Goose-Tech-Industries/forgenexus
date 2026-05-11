defmodule ForgeNexus.Repo.Migrations.CreateFlowExecutionAndState do
  use Ecto.Migration

  def change do
    create table(:flow_executions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :flow_id, references(:flows, type: :binary_id, on_delete: :delete_all), null: false
      add :status, :string, null: false, default: "running"
      add :trigger_type, :string, null: false
      add :trigger_data, :map, default: %{}
      add :result, :map, default: %{}
      add :node_trace, {:array, :map}, default: []
      add :started_at, :utc_datetime, null: false
      add :finished_at, :utc_datetime
      add :duration_ms, :integer
      add :nodes_executed, :integer, default: 0
      add :db_operations, :integer, default: 0
      add :http_requests, :integer, default: 0
      add :triggered_by_id, :binary_id

      timestamps()
    end

    create index(:flow_executions, [:flow_id])
    create index(:flow_executions, [:flow_id, :status])
    create index(:flow_executions, [:flow_id, :inserted_at])
    create index(:flow_executions, [:triggered_by_id])
    create index(:flow_executions, [:status])

    create table(:flow_global_store, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :flow_id, references(:flows, type: :binary_id, on_delete: :delete_all), null: false
      add :key, :string, null: false
      add :value, :map, default: %{}
      add :expires_at, :utc_datetime

      timestamps()
    end

    create unique_index(:flow_global_store, [:flow_id, :key])
    create index(:flow_global_store, [:expires_at])

    create table(:plugin_pages, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :flow_id, references(:flows, type: :binary_id, on_delete: :delete_all), null: false
      add :slug, :string, null: false
      add :title, :string, null: false
      add :description, :text
      add :template, :map, default: %{}
      add :is_published, :boolean, default: false
      add :nav_position, :integer
      add :nav_label, :string

      timestamps()
    end

    create unique_index(:plugin_pages, [:slug])
    create index(:plugin_pages, [:flow_id])
    create index(:plugin_pages, [:is_published])

    create table(:plugin_widgets, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :flow_id, references(:flows, type: :binary_id, on_delete: :delete_all), null: false
      add :placement, :string, null: false
      add :template, :map, default: %{}
      add :priority, :integer, default: 0
      add :is_active, :boolean, default: true
      add :conditions, :map, default: %{}

      timestamps()
    end

    create index(:plugin_widgets, [:flow_id])
    create index(:plugin_widgets, [:placement, :is_active])

    create table(:flow_rate_limits, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :flow_id, references(:flows, type: :binary_id, on_delete: :delete_all), null: false
      add :window_start, :utc_datetime, null: false
      add :window_seconds, :integer, null: false, default: 3600
      add :execution_count, :integer, null: false, default: 0

      timestamps()
    end

    create unique_index(:flow_rate_limits, [:flow_id, :window_start])
  end
end
