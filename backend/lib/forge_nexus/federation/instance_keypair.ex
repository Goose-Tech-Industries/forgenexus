defmodule ForgeNexus.Federation.InstanceKeypair do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "instance_keypairs" do
    field :public_key, :string
    field :private_key_encrypted, :binary
    field :is_active, :boolean, default: false

    timestamps()
  end

  def changeset(keypair, attrs) do
    keypair
    |> cast(attrs, [:public_key, :private_key_encrypted, :is_active])
    |> validate_required([:public_key, :private_key_encrypted])
  end
end
