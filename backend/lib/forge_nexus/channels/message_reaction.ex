defmodule ForgeNexus.Channels.MessageReaction do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "chat_message_reactions" do
    field :emoji, :string

    belongs_to :message, ForgeNexus.Channels.ChannelMessage
    belongs_to :user, ForgeNexus.Accounts.User

    timestamps()
  end

  def changeset(reaction, attrs) do
    reaction
    |> cast(attrs, [:emoji, :message_id, :user_id])
    |> validate_required([:emoji, :message_id, :user_id])
    |> validate_length(:emoji, min: 1, max: 64)
    |> unique_constraint([:message_id, :user_id, :emoji])
    |> foreign_key_constraint(:message_id)
    |> foreign_key_constraint(:user_id)
  end
end
