defmodule ForgeNexus.Houses.HouseInvitation do
  @moduledoc """
  Pending invitation to a House (a multi-creator community). The plaintext
  token only exists in the link the founder shares; the DB stores SHA-256.
  Mirrors the same pattern as ForgeNexus.Accounts.AuthToken so a DB leak
  cannot replay outstanding invites.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @roles ~w(creator admin)

  schema "house_invitations" do
    field :email, :string
    field :token_hash, :string
    field :role, :string, default: "creator"
    field :accepted_at, :utc_datetime
    field :expires_at, :utc_datetime

    belongs_to :community, ForgeNexus.Communities.Community
    belongs_to :inviter, ForgeNexus.Accounts.User
    belongs_to :accepted_by, ForgeNexus.Accounts.User, foreign_key: :accepted_by_user_id

    timestamps()
  end

  def changeset(invite, attrs) do
    invite
    |> cast(attrs, [:community_id, :inviter_id, :email, :token_hash, :role, :expires_at, :accepted_at, :accepted_by_user_id])
    |> validate_required([:community_id, :email, :token_hash, :expires_at])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+\.[^\s]+$/)
    |> validate_inclusion(:role, @roles)
    |> unique_constraint(:token_hash)
  end

  @doc "SHA-256 of the plaintext token, hex-encoded. Compared against `token_hash`."
  def hash(plaintext) when is_binary(plaintext) do
    :crypto.hash(:sha256, plaintext) |> Base.encode16(case: :lower)
  end
end
