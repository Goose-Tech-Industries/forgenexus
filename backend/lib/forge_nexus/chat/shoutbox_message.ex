defmodule ForgeNexus.Chat.ShoutboxMessage do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "shoutbox_messages" do
    field :body, :string
    field :body_html, :string
    field :is_pinned, :boolean, default: false
    field :is_system, :boolean, default: false
    field :is_deleted, :boolean, default: false

    belongs_to :user, ForgeNexus.Accounts.User

    timestamps()
  end

  def changeset(message, attrs) do
    message
    |> cast(attrs, [:user_id, :body, :body_html, :is_pinned, :is_system, :is_deleted])
    |> validate_required([:user_id, :body])
    |> validate_length(:body, min: 1, max: 500)
    |> foreign_key_constraint(:user_id)
  end
end
