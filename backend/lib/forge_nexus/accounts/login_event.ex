defmodule ForgeNexus.Accounts.LoginEvent do
  @moduledoc """
  Records each login attempt (success or failure) for audit, analytics,
  and rate-limiting. Backed by the `login_attempts` table.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "login_attempts" do
    field :email, :string
    field :ip_address, :string
    field :user_agent, :string
    field :success, :boolean, default: false
    field :failure_reason, :string
    field :occurred_at, :utc_datetime_usec

    belongs_to :user, ForgeNexus.Accounts.User

    timestamps(updated_at: false)
  end

  def changeset(event, attrs) do
    event
    |> cast(attrs, [
      :email,
      :ip_address,
      :user_agent,
      :success,
      :failure_reason,
      :occurred_at,
      :user_id
    ])
    |> validate_required([:success])
  end
end
