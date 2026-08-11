defmodule ForgeNexus.Accounts.LoginSession do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "login_sessions" do
    field :token_jti, :string
    field :ip_address, :string
    field :user_agent, :string
    field :device_name, :string
    field :last_active_at, :utc_datetime
    field :revoked_at, :utc_datetime
    field :refresh_token, :string

    belongs_to :user, ForgeNexus.Accounts.User

    timestamps()
  end

  def changeset(session, attrs) do
    session
    |> cast(attrs, [
      :token_jti,
      :ip_address,
      :user_agent,
      :device_name,
      :last_active_at,
      :user_id,
      :refresh_token
    ])
    |> validate_required([:token_jti, :user_id])
    |> unique_constraint(:token_jti)
    |> foreign_key_constraint(:user_id)
  end

  def active?(%__MODULE__{revoked_at: nil}), do: true
  def active?(_), do: false

  def parse_device_name(user_agent) when is_binary(user_agent) do
    cond do
      String.contains?(user_agent, "Mobile") -> "Mobile Browser"
      String.contains?(user_agent, "Chrome") -> "Chrome"
      String.contains?(user_agent, "Firefox") -> "Firefox"
      String.contains?(user_agent, "Safari") -> "Safari"
      String.contains?(user_agent, "Edge") -> "Edge"
      true -> "Unknown Device"
    end
  end

  def parse_device_name(_), do: "Unknown Device"
end
