defmodule ForgeNexus.Social.CommunityTemplate do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @categories ~w(gaming creative education business sports social music art tech community)

  schema "community_templates" do
    field :name, :string
    field :description, :string
    field :category, :string
    field :preview_url, :string
    field :template_data, :map
    field :price_cents, :integer, default: 0
    field :is_free, :boolean, default: true
    field :install_count, :integer, default: 0
    field :rating, :float, default: 0.0
    field :is_published, :boolean, default: false

    belongs_to :creator, ForgeNexus.Accounts.User

    timestamps()
  end

  def changeset(template, attrs) do
    template
    |> cast(attrs, [
      :creator_id,
      :name,
      :description,
      :category,
      :preview_url,
      :template_data,
      :price_cents,
      :is_free,
      :is_published
    ])
    |> validate_required([:name, :template_data])
    |> validate_inclusion(:category, @categories)
  end

  def categories, do: @categories
end
