defmodule ForgeNexus.Plugins.FlowGlobalStore do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "flow_global_store" do
    field :key, :string
    field :value, :map, default: %{}
    field :expires_at, :utc_datetime

    belongs_to :flow, ForgeNexus.Plugins.Flow

    timestamps()
  end

  def changeset(store, attrs) do
    store
    |> cast(attrs, [:flow_id, :key, :value, :expires_at])
    |> validate_required([:flow_id, :key])
    |> unique_constraint([:flow_id, :key])
    |> foreign_key_constraint(:flow_id)
  end
end
