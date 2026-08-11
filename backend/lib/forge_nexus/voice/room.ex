defmodule ForgeNexus.Voice.Room do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "voice_rooms" do
    field :name, :string
    field :slug, :string
    field :type, :string, default: "lounge"
    field :max_participants, :integer, default: 50
    field :is_locked, :boolean, default: false
    field :is_active, :boolean, default: true
    field :position, :integer, default: 0
    field :is_private, :boolean, default: false
    field :allowed_group_ids, {:array, :binary_id}, default: []
    field :scheduled_at, :utc_datetime
    field :description, :string

    belongs_to :community, ForgeNexus.Communities.Community
    belongs_to :channel, ForgeNexus.Channels.Channel
    belongs_to :category, ForgeNexus.Channels.ChannelCategory
    belongs_to :created_by, ForgeNexus.Accounts.User

    timestamps()
  end

  def changeset(room, attrs) do
    room
    |> cast(attrs, [
      :name,
      :slug,
      :type,
      :channel_id,
      :category_id,
      :community_id,
      :max_participants,
      :is_locked,
      :is_active,
      :position,
      :is_private,
      :allowed_group_ids,
      :created_by_id,
      :scheduled_at,
      :description
    ])
    |> validate_required([:name])
    |> validate_inclusion(:type, ["lounge", "huddle", "town_hall"])
    |> validate_number(:max_participants, greater_than: 0, less_than_or_equal_to: 500)
    |> generate_slug()
    |> unique_constraint(:slug)
    |> foreign_key_constraint(:community_id)
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
