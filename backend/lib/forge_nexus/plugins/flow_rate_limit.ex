defmodule ForgeNexus.Plugins.FlowRateLimit do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "flow_rate_limits" do
    field :window_start, :utc_datetime
    field :window_seconds, :integer, default: 3600
    field :execution_count, :integer, default: 0

    belongs_to :flow, ForgeNexus.Plugins.Flow

    timestamps()
  end

  def changeset(limit, attrs) do
    limit
    |> cast(attrs, [:flow_id, :window_start, :window_seconds, :execution_count])
    |> validate_required([:flow_id, :window_start])
    |> unique_constraint([:flow_id, :window_start])
    |> foreign_key_constraint(:flow_id)
  end
end
