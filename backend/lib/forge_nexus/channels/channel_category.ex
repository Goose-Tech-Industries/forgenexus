defmodule ForgeNexus.Channels.ChannelCategory do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "chat_channel_categories" do
    field :name, :string
    field :slug, :string
    field :position, :integer, default: 0
    field :is_collapsed, :boolean, default: false

    has_many :channels, ForgeNexus.Channels.Channel, foreign_key: :category_id

    timestamps()
  end

  def changeset(category, attrs) do
    category
    |> cast(attrs, [:name, :slug, :position, :is_collapsed])
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
