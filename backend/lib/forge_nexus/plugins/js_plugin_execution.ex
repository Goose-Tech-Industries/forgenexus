defmodule ForgeNexus.Plugins.JsPluginExecution do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @statuses ~w(running completed failed timeout)

  schema "js_plugin_executions" do
    field :status, :string, default: "running"
    field :trigger_type, :string
    field :trigger_data, :map, default: %{}
    field :result, :map, default: %{}
    field :logs, {:array, :string}, default: []
    field :started_at, :utc_datetime
    field :finished_at, :utc_datetime
    field :duration_ms, :integer
    field :triggered_by_id, :binary_id

    belongs_to :js_plugin, ForgeNexus.Plugins.JsPlugin

    timestamps()
  end

  def changeset(execution, attrs) do
    execution
    |> cast(attrs, [:js_plugin_id, :status, :trigger_type, :trigger_data, :started_at, :triggered_by_id])
    |> validate_required([:js_plugin_id, :started_at])
    |> validate_inclusion(:status, @statuses)
    |> foreign_key_constraint(:js_plugin_id)
  end

  def complete_changeset(execution, attrs) do
    execution
    |> cast(attrs, [:status, :result, :logs, :finished_at, :duration_ms])
    |> validate_inclusion(:status, @statuses)
  end
end
