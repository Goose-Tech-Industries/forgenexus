defmodule ForgeNexus.Federation.FederatedIdentity do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "federated_identities" do
    field :remote_user_id, :string
    field :remote_username, :string
    field :remote_display_name, :string
    field :portable_reputation, :map
    field :last_synced_at, :utc_datetime

    belongs_to :local_user, ForgeNexus.Accounts.User
    belongs_to :remote_instance, ForgeNexus.Federation.FederatedInstance

    timestamps()
  end

  def changeset(identity, attrs) do
    identity
    |> cast(attrs, [
      :remote_user_id, :remote_username, :remote_display_name,
      :portable_reputation, :last_synced_at, :local_user_id, :remote_instance_id
    ])
    |> validate_required([:remote_user_id, :remote_username, :local_user_id, :remote_instance_id])
    |> foreign_key_constraint(:local_user_id)
    |> foreign_key_constraint(:remote_instance_id)
  end
end
