defmodule ForgeNexus.Chat.Message do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "messages" do
    field :body, :string
    field :body_html, :string
    field :is_edited, :boolean, default: false
    field :edited_at, :utc_datetime
    field :is_system, :boolean, default: false
    field :is_deleted, :boolean, default: false
    field :reactions, :map, default: %{}

    belongs_to :conversation, ForgeNexus.Chat.Conversation
    belongs_to :user, ForgeNexus.Accounts.User
    belongs_to :reply_to, __MODULE__

    timestamps()
  end

  def changeset(message, attrs) do
    message
    |> cast(attrs, [:body, :body_html, :is_system, :conversation_id, :user_id, :reply_to_id])
    |> validate_required([:body, :conversation_id, :user_id])
    |> validate_length(:body, min: 1, max: 10_000)
  end
end
