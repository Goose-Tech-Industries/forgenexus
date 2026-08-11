defmodule ForgeNexus.Accounts.UserGroup do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "user_groups" do
    field :name, :string
    field :slug, :string
    field :description, :string
    field :color, :string
    field :icon, :string
    field :is_default, :boolean, default: false
    field :is_staff, :boolean, default: false
    field :position, :integer, default: 0
    field :permissions, :map, default: %{}
    field :username_color, :string
    field :username_effect, :string

    has_many :memberships, ForgeNexus.Accounts.UserGroupMembership, foreign_key: :group_id
    has_many :users, through: [:memberships, :user]

    timestamps()
  end

  def changeset(group, attrs) do
    group
    |> cast(attrs, [
      :name,
      :slug,
      :description,
      :color,
      :icon,
      :is_default,
      :is_staff,
      :position,
      :permissions
    ])
    |> validate_required([:name])
    |> generate_slug()
    |> unique_constraint(:slug)
  end

  def admin_changeset(group, attrs) do
    group
    |> cast(attrs, [
      :name,
      :slug,
      :description,
      :color,
      :icon,
      :is_default,
      :is_staff,
      :position,
      :permissions,
      :username_color,
      :username_effect
    ])
    |> validate_required([:name])
    |> generate_slug()
    |> unique_constraint(:slug)
  end

  defp generate_slug(changeset) do
    case get_change(changeset, :name) do
      nil ->
        changeset

      name ->
        slug = get_change(changeset, :slug) || Slug.slugify(name)
        put_change(changeset, :slug, slug)
    end
  end
end
