defmodule ForgeNexus.Forums.ThreadPrefix do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "thread_prefixes" do
    field :name, :string
    field :color, :string, default: "#6366f1"
    field :bg_color, :string
    field :is_global, :boolean, default: false
    field :position, :integer, default: 0

    belongs_to :forum, ForgeNexus.Forums.Forum

    timestamps()
  end

  def changeset(prefix, attrs) do
    prefix
    |> cast(attrs, [:name, :color, :bg_color, :forum_id, :is_global, :position])
    |> validate_required([:name])
    |> validate_length(:name, min: 1, max: 30)
  end
end
