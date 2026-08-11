defmodule ForgeNexus.Channels.ChannelMember do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "chat_channel_members" do
    field :last_read_at, :utc_datetime
    field :notification_level, :string, default: "all"
    field :is_muted, :boolean, default: false

    belongs_to :channel, ForgeNexus.Channels.Channel
    belongs_to :user, ForgeNexus.Accounts.User
    belongs_to :last_read_message, ForgeNexus.Channels.ChannelMessage

    timestamps()
  end

  def changeset(member, attrs) do
    member
    |> cast(attrs, [
      :channel_id,
      :user_id,
      :last_read_at,
      :last_read_message_id,
      :notification_level,
      :is_muted
    ])
    |> validate_required([:channel_id, :user_id])
    |> validate_inclusion(:notification_level, ["all", "mentions", "none"])
    |> unique_constraint([:channel_id, :user_id])
    |> foreign_key_constraint(:channel_id)
    |> foreign_key_constraint(:user_id)
  end
end
