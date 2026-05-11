defmodule ForgeNexus.Plugins.PluginWidget do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @placements ~w(profile_sidebar profile_header post_footer post_header thread_sidebar)

  schema "plugin_widgets" do
    field :placement, :string
    field :template, :map, default: %{}
    field :priority, :integer, default: 0
    field :is_active, :boolean, default: true
    field :conditions, :map, default: %{}

    belongs_to :flow, ForgeNexus.Plugins.Flow

    timestamps()
  end

  def changeset(widget, attrs) do
    widget
    |> cast(attrs, [:flow_id, :placement, :template, :priority, :is_active, :conditions])
    |> validate_required([:flow_id, :placement])
    |> validate_inclusion(:placement, @placements)
    |> foreign_key_constraint(:flow_id)
  end
end
