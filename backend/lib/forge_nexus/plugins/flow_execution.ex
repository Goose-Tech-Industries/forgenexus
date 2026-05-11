defmodule ForgeNexus.Plugins.FlowExecution do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @statuses ~w(running completed failed timeout cancelled)

  schema "flow_executions" do
    field :status, :string, default: "running"
    field :trigger_type, :string
    field :trigger_data, :map, default: %{}
    field :result, :map, default: %{}
    field :node_trace, {:array, :map}, default: []
    field :started_at, :utc_datetime
    field :finished_at, :utc_datetime
    field :duration_ms, :integer
    field :nodes_executed, :integer, default: 0
    field :db_operations, :integer, default: 0
    field :http_requests, :integer, default: 0
    field :triggered_by_id, :binary_id

    belongs_to :flow, ForgeNexus.Plugins.Flow

    timestamps()
  end

  def changeset(execution, attrs) do
    execution
    |> cast(attrs, [:flow_id, :status, :trigger_type, :trigger_data, :started_at, :triggered_by_id])
    |> validate_required([:flow_id, :trigger_type, :started_at])
    |> validate_inclusion(:status, @statuses)
    |> foreign_key_constraint(:flow_id)
  end

  def complete_changeset(execution, attrs) do
    execution
    |> cast(attrs, [:status, :result, :node_trace, :finished_at, :duration_ms, :nodes_executed, :db_operations, :http_requests])
    |> validate_inclusion(:status, @statuses)
  end
end
