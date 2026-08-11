defmodule ForgeNexus.Plugins.CustomDataColumn do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @data_types ~w(string integer float boolean json datetime)

  schema "custom_data_columns" do
    field :name, :string
    field :slug, :string
    field :data_type, :string
    field :default_value, :string
    field :is_required, :boolean, default: false
    field :is_indexed, :boolean, default: false
    field :is_unique, :boolean, default: false
    field :position, :integer, default: 0
    field :validations, :map, default: %{}

    belongs_to :table, ForgeNexus.Plugins.CustomDataTable

    timestamps()
  end

  def changeset(column, attrs) do
    column
    |> cast(attrs, [
      :table_id,
      :name,
      :slug,
      :data_type,
      :default_value,
      :is_required,
      :is_indexed,
      :is_unique,
      :position,
      :validations
    ])
    |> validate_required([:table_id, :name, :slug, :data_type])
    |> validate_inclusion(:data_type, @data_types)
    |> unique_constraint([:table_id, :slug])
    |> foreign_key_constraint(:table_id)
  end
end
