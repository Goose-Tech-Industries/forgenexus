defmodule ForgeNexus.Federation.FederatedInstance do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "federated_instances" do
    field :domain, :string
    field :name, :string
    field :description, :string
    field :public_key, :string
    field :software, :string
    field :software_version, :string
    field :trust_level, :string, default: "untrusted"
    field :status, :string, default: "pending"
    field :last_seen_at, :utc_datetime
    field :stats, :map

    timestamps()
  end

  def changeset(instance, attrs) do
    instance
    |> cast(attrs, [
      :domain,
      :name,
      :description,
      :public_key,
      :software,
      :software_version,
      :trust_level,
      :status,
      :last_seen_at,
      :stats
    ])
    |> validate_required([:domain])
    |> unique_constraint(:domain)
    |> validate_inclusion(:trust_level, ["trusted", "verified", "untrusted"])
    |> validate_inclusion(:status, ["active", "suspended", "pending", "blocked"])
  end
end
