defmodule ForgeNexus.Plugins.FlowNode do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @categories ~w(
    trigger logic math data action text ui
    achievement analytics approval automod collection content
    economy gambling integration inventory moderation notification
    pet poll profile quest reputation scheduling stats
    shoutbox ticket tournament user_management verification
  )

  schema "flow_nodes" do
    field :type, :string
    field :category, :string
    field :label, :string
    field :config, :map, default: %{}
    field :position_x, :float, default: 0.0
    field :position_y, :float, default: 0.0
    field :position, :integer, default: 0

    belongs_to :flow, ForgeNexus.Plugins.Flow

    timestamps()
  end

  def changeset(node, attrs) do
    node
    |> cast(attrs, [:flow_id, :type, :category, :label, :config, :position_x, :position_y, :position])
    |> validate_required([:flow_id, :type, :category])
    |> maybe_derive_category()
    |> validate_inclusion(:category, @categories)
    |> foreign_key_constraint(:flow_id)
  end

  # Derive category from the type field (e.g. "economy/award_points" -> "economy")
  # if no category was explicitly provided
  defp maybe_derive_category(changeset) do
    case {get_field(changeset, :category), get_field(changeset, :type)} do
      {nil, type} when is_binary(type) ->
        case String.split(type, "/", parts: 2) do
          [category, _rest] -> put_change(changeset, :category, category)
          _ -> changeset
        end

      _ ->
        changeset
    end
  end
end
