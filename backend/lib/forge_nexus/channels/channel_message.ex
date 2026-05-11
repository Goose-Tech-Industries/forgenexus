defmodule ForgeNexus.Channels.ChannelMessage do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "chat_messages" do
    field :body, :string

    # Features
    field :is_edited, :boolean, default: false
    field :edited_at, :utc_datetime
    field :is_pinned, :boolean, default: false
    field :pinned_at, :utc_datetime
    field :is_deleted, :boolean, default: false

    # Attachments & embeds
    field :attachments, {:array, :map}, default: []
    field :embeds, {:array, :map}, default: []

    belongs_to :channel, ForgeNexus.Channels.Channel
    belongs_to :user, ForgeNexus.Accounts.User
    belongs_to :reply_to, __MODULE__
    belongs_to :pinned_by, ForgeNexus.Accounts.User
    belongs_to :deleted_by, ForgeNexus.Accounts.User

    has_many :reactions, ForgeNexus.Channels.MessageReaction, foreign_key: :message_id
    belongs_to :thread, ForgeNexus.Channels.ChatThread
    has_one :spawned_thread, ForgeNexus.Channels.ChatThread, foreign_key: :parent_message_id

    timestamps()
  end

  def changeset(message, attrs) do
    message
    |> cast(attrs, [:body, :channel_id, :user_id, :reply_to_id, :attachments, :embeds])
    |> validate_required([:body, :channel_id, :user_id])
    |> validate_length(:body, min: 1, max: 10_000)
    |> foreign_key_constraint(:channel_id)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:reply_to_id)
  end

  def edit_changeset(message, attrs) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    message
    |> cast(attrs, [:body])
    |> validate_required([:body])
    |> validate_length(:body, min: 1, max: 10_000)
    |> put_change(:is_edited, true)
    |> put_change(:edited_at, now)
  end

  def pin_changeset(message, pinned_by_id) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    message
    |> change(is_pinned: true, pinned_by_id: pinned_by_id, pinned_at: now)
  end

  def unpin_changeset(message) do
    message
    |> change(is_pinned: false, pinned_by_id: nil, pinned_at: nil)
  end

  def delete_changeset(message, deleted_by_id) do
    message
    |> change(is_deleted: true, deleted_by_id: deleted_by_id)
  end
end
