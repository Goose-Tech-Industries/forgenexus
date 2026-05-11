defmodule ForgeNexus.Plugins.CustomDataTable do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @scopes ~w(global per_user per_thread per_forum)

  schema "custom_data_tables" do
    field :name, :string
    field :slug, :string
    field :description, :string
    field :scope, :string, default: "global"
    field :max_rows, :integer, default: 10000

    belongs_to :created_by, ForgeNexus.Accounts.User
    has_many :columns, ForgeNexus.Plugins.CustomDataColumn, foreign_key: :table_id
    has_many :rows, ForgeNexus.Plugins.CustomDataRow, foreign_key: :table_id

    timestamps()
  end

  def changeset(table, attrs) do
    table
    |> cast(attrs, [:name, :slug, :description, :scope, :max_rows, :created_by_id])
    |> validate_required([:name, :slug, :created_by_id])
    |> validate_inclusion(:scope, @scopes)
    |> validate_number(:max_rows, greater_than: 0, less_than_or_equal_to: 100_000)
    |> unique_constraint(:slug)
    |> foreign_key_constraint(:created_by_id)
  end
end
