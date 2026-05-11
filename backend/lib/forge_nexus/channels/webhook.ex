defmodule ForgeNexus.Channels.Webhook do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "chat_webhooks" do
    field :name, :string
    field :avatar_url, :string
    field :token, :string
    field :is_active, :boolean, default: true

    belongs_to :channel, ForgeNexus.Channels.Channel
    belongs_to :created_by, ForgeNexus.Accounts.User

    timestamps()
  end

  def changeset(webhook, attrs) do
    webhook
    |> cast(attrs, [:name, :avatar_url, :channel_id, :created_by_id, :is_active])
    |> validate_required([:name, :channel_id])
    |> validate_length(:name, min: 1, max: 80)
    |> put_token()
  end

  defp put_token(changeset) do
    if get_field(changeset, :token) do
      changeset
    else
      put_change(changeset, :token, generate_token())
    end
  end

  defp generate_token do
    :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
  end
end
