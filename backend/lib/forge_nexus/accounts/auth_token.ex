defmodule ForgeNexus.Accounts.AuthToken do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @valid_types ~w(email_verify password_reset email_change)

  schema "auth_tokens" do
    field :token_hash, :string
    field :type, :string
    field :email, :string
    field :used_at, :utc_datetime
    field :expires_at, :utc_datetime

    belongs_to :user, ForgeNexus.Accounts.User

    timestamps()
  end

  def changeset(auth_token, attrs) do
    auth_token
    |> cast(attrs, [:token_hash, :type, :email, :expires_at, :user_id])
    |> validate_required([:token_hash, :type, :expires_at, :user_id])
    |> validate_inclusion(:type, @valid_types)
    |> unique_constraint(:token_hash)
    |> foreign_key_constraint(:user_id)
  end

  @doc "SHA-256 hash a plaintext token so only the digest is stored in the DB."
  def hash(plaintext) when is_binary(plaintext) do
    :crypto.hash(:sha256, plaintext) |> Base.url_encode64(padding: false)
  end

  def expired?(%__MODULE__{expires_at: expires_at}) do
    DateTime.compare(DateTime.utc_now(), expires_at) == :gt
  end

  def used?(%__MODULE__{used_at: used_at}), do: !is_nil(used_at)
end
