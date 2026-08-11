defmodule ForgeNexus.Federation.FederationPolicy do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "federation_policies" do
    field :mode, :string, default: "closed"
    field :allowed_domains, :map
    field :blocked_domains, :map
    field :auto_accept_follows, :boolean, default: false
    field :share_user_profiles, :boolean, default: false

    timestamps()
  end

  def changeset(policy, attrs) do
    policy
    |> cast(attrs, [
      :mode,
      :allowed_domains,
      :blocked_domains,
      :auto_accept_follows,
      :share_user_profiles
    ])
    |> validate_required([:mode])
    |> validate_inclusion(:mode, ["open", "allowlist", "closed"])
  end
end
