defmodule ForgeNexus.Voice.DmCall do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "dm_calls" do
    field :status, :string, default: "ringing"
    field :type, :string, default: "audio"
    field :started_at, :utc_datetime
    field :answered_at, :utc_datetime
    field :ended_at, :utc_datetime
    field :participant_ids, {:array, :binary_id}, default: []

    belongs_to :conversation, ForgeNexus.Chat.Conversation
    belongs_to :caller, ForgeNexus.Accounts.User

    timestamps()
  end

  def changeset(call, attrs) do
    call
    |> cast(attrs, [
      :conversation_id,
      :caller_id,
      :status,
      :type,
      :started_at,
      :answered_at,
      :ended_at,
      :participant_ids
    ])
    |> validate_required([:conversation_id, :caller_id])
    |> validate_inclusion(:status, ["ringing", "active", "ended", "missed", "declined"])
    |> validate_inclusion(:type, ["audio", "video"])
  end
end
