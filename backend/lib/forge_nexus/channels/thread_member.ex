defmodule ForgeNexus.Channels.ThreadMember do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "chat_thread_members" do
    belongs_to :thread, ForgeNexus.Channels.ChatThread
    belongs_to :user, ForgeNexus.Accounts.User
    field :last_read_at, :utc_datetime

    timestamps()
  end

  def changeset(member, attrs) do
    member
    |> cast(attrs, [:thread_id, :user_id, :last_read_at])
    |> validate_required([:thread_id, :user_id])
    |> unique_constraint([:thread_id, :user_id])
  end
end
