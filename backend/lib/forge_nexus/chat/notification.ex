defmodule ForgeNexus.Chat.Notification do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "notifications" do
    field :type, :string
    field :title, :string
    field :body, :string
    field :is_read, :boolean, default: false
    field :read_at, :utc_datetime
    field :url, :string
    field :metadata, :map, default: %{}

    belongs_to :user, ForgeNexus.Accounts.User
    belongs_to :actor, ForgeNexus.Accounts.User

    timestamps()
  end

  def changeset(notification, attrs) do
    notification
    |> cast(attrs, [:type, :title, :body, :url, :metadata, :user_id, :actor_id])
    |> validate_required([:type, :title, :user_id])
  end

  def read_changeset(notification) do
    notification
    |> change(is_read: true, read_at: DateTime.utc_now() |> DateTime.truncate(:second))
  end
end
