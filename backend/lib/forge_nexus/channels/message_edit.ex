defmodule ForgeNexus.Channels.MessageEdit do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "chat_message_edits" do
    field :previous_body, :string

    belongs_to :message, ForgeNexus.Channels.ChannelMessage
    belongs_to :edited_by, ForgeNexus.Accounts.User

    timestamps()
  end

  def changeset(edit, attrs) do
    edit
    |> cast(attrs, [:message_id, :previous_body, :edited_by_id])
    |> validate_required([:message_id, :previous_body, :edited_by_id])
    |> foreign_key_constraint(:message_id)
    |> foreign_key_constraint(:edited_by_id)
  end
end
