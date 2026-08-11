defmodule ForgeNexus.Platform.ApiKey do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @plans %{
    "free" => %{rate_limit: 100, scopes: ["read"]},
    "basic" => %{rate_limit: 1000, scopes: ["read", "write"]},
    "pro" => %{rate_limit: 5000, scopes: ["read", "write", "admin"]},
    "enterprise" => %{rate_limit: 10000, scopes: ["read", "write", "admin", "webhooks"]}
  }

  @all_scopes ~w(read write admin webhooks economy voice streaming moderation)

  schema "api_keys" do
    field :name, :string
    field :key_hash, :string
    field :key_prefix, :string
    field :scopes, {:array, :string}, default: ["read"]
    field :rate_limit_per_minute, :integer, default: 100
    field :plan, :string, default: "free"
    field :is_active, :boolean, default: true
    field :last_used_at, :utc_datetime
    field :total_requests, :integer, default: 0
    field :expires_at, :utc_datetime

    belongs_to :community, ForgeNexus.Communities.Community
    belongs_to :user, ForgeNexus.Accounts.User

    timestamps()
  end

  def changeset(key, attrs) do
    key
    |> cast(attrs, [
      :community_id,
      :user_id,
      :name,
      :key_hash,
      :key_prefix,
      :scopes,
      :rate_limit_per_minute,
      :plan,
      :is_active,
      :expires_at
    ])
    |> validate_required([:name, :key_hash, :key_prefix, :user_id])
    |> validate_length(:name, max: 100)
    |> unique_constraint(:key_hash)
  end

  def generate_key do
    raw = "fnx_" <> Base.url_encode64(:crypto.strong_rand_bytes(32), padding: false)
    prefix = String.slice(raw, 0, 8)
    hash = :crypto.hash(:sha256, raw) |> Base.encode16(case: :lower)
    {raw, prefix, hash}
  end

  def plans, do: @plans
  def all_scopes, do: @all_scopes
end
