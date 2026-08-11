defmodule ForgeNexus.Repo.Migrations.CreateFlowsAndNodes do
  use Ecto.Migration

  def change do
    create table(:flows, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :description, :text
      add :slug, :string, null: false
      add :status, :string, null: false, default: "draft"
      add :tier, :string, null: false, default: "nocode"
      add :version, :integer, null: false, default: 1
      add :trigger_type, :string, null: false
      add :trigger_config, :map, default: %{}
      add :settings, :map, default: %{}
      add :error_message, :text
      add :last_executed_at, :utc_datetime
      add :execution_count, :integer, default: 0

      add :created_by_id, references(:users, type: :binary_id, on_delete: :nilify_all),
        null: false

      timestamps()
    end

    create unique_index(:flows, [:slug])
    create index(:flows, [:status])
    create index(:flows, [:trigger_type])
    create index(:flows, [:created_by_id])

    create table(:flow_nodes, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :flow_id, references(:flows, type: :binary_id, on_delete: :delete_all), null: false
      add :type, :string, null: false
      add :category, :string, null: false
      add :label, :string
      add :config, :map, default: %{}
      add :position_x, :float, default: 0.0
      add :position_y, :float, default: 0.0
      add :position, :integer, default: 0

      timestamps()
    end

    create index(:flow_nodes, [:flow_id])
    create index(:flow_nodes, [:flow_id, :type])

    create table(:flow_edges, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :flow_id, references(:flows, type: :binary_id, on_delete: :delete_all), null: false

      add :source_node_id, references(:flow_nodes, type: :binary_id, on_delete: :delete_all),
        null: false

      add :target_node_id, references(:flow_nodes, type: :binary_id, on_delete: :delete_all),
        null: false

      add :source_port, :string, default: "output"
      add :target_port, :string, default: "input"
      add :condition, :string
      add :position, :integer, default: 0

      timestamps()
    end

    create index(:flow_edges, [:flow_id])
    create index(:flow_edges, [:source_node_id])
    create index(:flow_edges, [:target_node_id])
  end
end
