defmodule ForgeNexus.Chat.ConversationParticipant do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "conversation_participants" do
    field :role, :string, default: "member"
    field :last_read_at, :utc_datetime
    field :is_muted, :boolean, default: false
    field :joined_at, :utc_datetime

    belongs_to :conversation, ForgeNexus.Chat.Conversation
    belongs_to :user, ForgeNexus.Accounts.User

    timestamps()
  end

  def changeset(participant, attrs) do
    participant
    |> cast(attrs, [:role, :is_muted, :conversation_id, :user_id])
    |> validate_required([:conversation_id, :user_id])
    |> put_joined_at()
    |> unique_constraint([:conversation_id, :user_id])
  end

  defp put_joined_at(changeset) do
    case get_field(changeset, :joined_at) do
      nil -> put_change(changeset, :joined_at, DateTime.utc_now() |> DateTime.truncate(:second))
      _ -> changeset
    end
  end
end
