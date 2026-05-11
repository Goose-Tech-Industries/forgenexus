defmodule ForgeNexus.Accounts.AvatarFrame do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "avatar_frames" do
    field :name, :string
    field :slug, :string
    field :css_class, :string
    field :description, :string
    field :min_posts, :integer
    field :is_active, :boolean, default: true
    field :position, :integer, default: 0

    timestamps()
  end

  def changeset(frame, attrs) do
    frame
    |> cast(attrs, [:name, :slug, :css_class, :description, :min_posts, :is_active, :position])
    |> validate_required([:name, :slug, :css_class])
    |> unique_constraint(:slug)
  end
end
