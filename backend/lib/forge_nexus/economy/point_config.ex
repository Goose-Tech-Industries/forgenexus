defmodule ForgeNexus.Economy.PointConfig do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "point_config" do
    field :action, :string
    field :points, :integer
    field :is_active, :boolean, default: true
    timestamps()
  end

  def changeset(pc, attrs) do
    pc
    |> cast(attrs, [:action, :points, :is_active])
    |> validate_required([:action, :points])
    |> unique_constraint(:action)
  end
end
