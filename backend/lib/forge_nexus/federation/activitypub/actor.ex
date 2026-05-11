defmodule ForgeNexus.Federation.ActivityPub.Actor do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "ap_actors" do
    field :uri, :string
    field :type, :string
    field :inbox_url, :string
    field :outbox_url, :string
    field :followers_url, :string
    field :public_key_pem, :string
    field :private_key_pem_encrypted, :binary
    field :followers_count, :integer, default: 0
    field :following_count, :integer, default: 0
    field :is_local, :boolean, default: false

    belongs_to :local_forum, ForgeNexus.Forums.Forum
    belongs_to :local_user, ForgeNexus.Accounts.User

    timestamps()
  end

  def changeset(actor, attrs) do
    actor
    |> cast(attrs, [
      :uri, :type, :inbox_url, :outbox_url, :followers_url,
      :public_key_pem, :private_key_pem_encrypted,
      :followers_count, :following_count, :is_local,
      :local_forum_id, :local_user_id
    ])
    |> validate_required([:uri, :type, :inbox_url])
    |> unique_constraint(:uri)
  end
end
