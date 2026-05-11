defmodule ForgeNexus.Channels.MessageBookmark do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "chat_message_bookmarks" do
    belongs_to :message, ForgeNexus.Channels.ChannelMessage
    belongs_to :user, ForgeNexus.Accounts.User
    field :note, :string

    timestamps()
  end

  def changeset(bookmark, attrs) do
    bookmark
    |> cast(attrs, [:message_id, :user_id, :note])
    |> validate_required([:message_id, :user_id])
    |> unique_constraint([:message_id, :user_id])
  end
end
