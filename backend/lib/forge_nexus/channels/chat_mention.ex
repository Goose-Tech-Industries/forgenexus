defmodule ForgeNexus.Channels.ChatMention do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "chat_mentions" do
    field :mention_type, :string, default: "user"
    field :read, :boolean, default: false

    belongs_to :message, ForgeNexus.Channels.ChannelMessage
    belongs_to :mentioned_user, ForgeNexus.Accounts.User

    timestamps()
  end

  def changeset(mention, attrs) do
    mention
    |> cast(attrs, [:message_id, :mentioned_user_id, :mention_type, :read])
    |> validate_required([:message_id, :mentioned_user_id])
    |> validate_inclusion(:mention_type, ["user", "group", "everyone", "here"])
    |> unique_constraint([:message_id, :mentioned_user_id])
    |> foreign_key_constraint(:message_id)
    |> foreign_key_constraint(:mentioned_user_id)
  end
end
