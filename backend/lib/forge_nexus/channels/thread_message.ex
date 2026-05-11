defmodule ForgeNexus.Channels.ThreadMessage do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "chat_thread_messages" do
    field :body, :string
    field :is_edited, :boolean, default: false
    field :edited_at, :utc_datetime
    field :is_deleted, :boolean, default: false

    belongs_to :thread, ForgeNexus.Channels.ChatThread
    belongs_to :user, ForgeNexus.Accounts.User

    timestamps()
  end

  def changeset(msg, attrs) do
    msg
    |> cast(attrs, [:body, :thread_id, :user_id])
    |> validate_required([:body, :thread_id, :user_id])
    |> validate_length(:body, min: 1, max: 10_000)
  end

  def edit_changeset(msg, attrs) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    msg
    |> cast(attrs, [:body])
    |> validate_required([:body])
    |> validate_length(:body, min: 1, max: 10_000)
    |> put_change(:is_edited, true)
    |> put_change(:edited_at, now)
  end
end
