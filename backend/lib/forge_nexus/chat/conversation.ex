defmodule ForgeNexus.Chat.Conversation do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "conversations" do
    field :title, :string
    field :type, :string, default: "direct"
    field :last_message_at, :utc_datetime
    field :message_count, :integer, default: 0

    belongs_to :creator, ForgeNexus.Accounts.User
    has_many :participants, ForgeNexus.Chat.ConversationParticipant
    has_many :users, through: [:participants, :user]
    has_many :messages, ForgeNexus.Chat.Message

    timestamps()
  end

  def changeset(conversation, attrs) do
    conversation
    |> cast(attrs, [:title, :type, :creator_id])
    |> validate_required([:type])
    |> validate_inclusion(:type, ["direct", "group"])
  end
end
