defmodule ForgeNexus.Plugins.CustomDataRow do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "custom_data_rows" do
    field :scope_id, :binary_id
    field :data, :map, default: %{}
    field :version, :integer, default: 1

    belongs_to :table, ForgeNexus.Plugins.CustomDataTable

    timestamps()
  end

  def changeset(row, attrs) do
    row
    |> cast(attrs, [:table_id, :scope_id, :data])
    |> validate_required([:table_id, :data])
    |> foreign_key_constraint(:table_id)
  end

  def update_changeset(row, attrs) do
    row
    |> cast(attrs, [:data])
    |> validate_required([:data])
    |> optimistic_lock(:version)
  end
end
