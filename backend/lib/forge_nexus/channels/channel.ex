defmodule ForgeNexus.Channels.Channel do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "chat_channels" do
    field :name, :string
    field :slug, :string
    field :description, :string
    field :topic, :string
    field :type, :string, default: "text"
    field :icon, :string
    field :color, :string
    field :position, :integer, default: 0

    # Permissions
    field :is_private, :boolean, default: false
    field :allowed_group_ids, {:array, :binary_id}, default: []
    field :is_read_only, :boolean, default: false
    field :slowmode_seconds, :integer, default: 0
    field :is_nsfw, :boolean, default: false
    field :is_archived, :boolean, default: false

    # Metadata
    field :last_message_at, :utc_datetime
    field :message_count, :integer, default: 0

    belongs_to :category, ForgeNexus.Channels.ChannelCategory
    belongs_to :created_by, ForgeNexus.Accounts.User
    has_many :messages, ForgeNexus.Channels.ChannelMessage
    has_many :members, ForgeNexus.Channels.ChannelMember

    timestamps()
  end

  def changeset(channel, attrs) do
    channel
    |> cast(attrs, [
      :name,
      :slug,
      :description,
      :topic,
      :type,
      :icon,
      :color,
      :position,
      :category_id,
      :is_private,
      :allowed_group_ids,
      :is_read_only,
      :slowmode_seconds,
      :is_nsfw,
      :is_archived,
      :created_by_id
    ])
    |> validate_required([:name])
    |> validate_inclusion(:type, ["text", "voice", "announcements"])
    |> validate_number(:slowmode_seconds, greater_than_or_equal_to: 0)
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
