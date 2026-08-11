defmodule ForgeNexus.ThreadTypes.ThreadType do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "thread_types" do
    field :name, :string
    field :slug, :string
    field :label, :string
    field :icon, :string
    field :description, :string
    field :config, :map, default: %{}
    field :is_builtin, :boolean, default: false
    field :is_active, :boolean, default: true
    field :position, :integer, default: 0

    belongs_to :created_by, ForgeNexus.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(struct, attrs) do
    struct
    |> cast(attrs, [
      :name,
      :slug,
      :label,
      :icon,
      :description,
      :config,
      :is_builtin,
      :is_active,
      :position,
      :created_by_id
    ])
    |> validate_required([:name, :slug, :label])
    |> unique_constraint(:slug)
  end
end
