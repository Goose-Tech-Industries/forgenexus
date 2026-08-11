defmodule ForgeNexus.Plugins.FlowEdge do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "flow_edges" do
    field :source_port, :string, default: "output"
    field :target_port, :string, default: "input"
    field :condition, :string
    field :position, :integer, default: 0

    belongs_to :flow, ForgeNexus.Plugins.Flow
    belongs_to :source_node, ForgeNexus.Plugins.FlowNode
    belongs_to :target_node, ForgeNexus.Plugins.FlowNode

    timestamps()
  end

  def changeset(edge, attrs) do
    edge
    |> cast(attrs, [
      :flow_id,
      :source_node_id,
      :target_node_id,
      :source_port,
      :target_port,
      :condition,
      :position
    ])
    |> validate_required([:flow_id, :source_node_id, :target_node_id])
    |> foreign_key_constraint(:flow_id)
    |> foreign_key_constraint(:source_node_id)
    |> foreign_key_constraint(:target_node_id)
  end
end
