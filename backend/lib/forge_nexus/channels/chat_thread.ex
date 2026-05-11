defmodule ForgeNexus.Channels.ChatThread do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "chat_threads" do
    field :name, :string
    field :is_archived, :boolean, default: false
    field :is_locked, :boolean, default: false
    field :message_count, :integer, default: 0
    field :last_message_at, :utc_datetime
    field :auto_archive_minutes, :integer, default: 1440

    belongs_to :channel, ForgeNexus.Channels.Channel
    belongs_to :parent_message, ForgeNexus.Channels.ChannelMessage
    belongs_to :created_by, ForgeNexus.Accounts.User
    has_many :messages, ForgeNexus.Channels.ThreadMessage, foreign_key: :thread_id
    has_many :members, ForgeNexus.Channels.ThreadMember, foreign_key: :thread_id

    timestamps()
  end

  def changeset(thread, attrs) do
    thread
    |> cast(attrs, [:name, :channel_id, :parent_message_id, :created_by_id, :is_archived, :is_locked, :auto_archive_minutes])
    |> validate_required([:name, :channel_id, :parent_message_id, :created_by_id])
    |> validate_length(:name, min: 1, max: 100)
    |> unique_constraint(:parent_message_id)
  end
end
