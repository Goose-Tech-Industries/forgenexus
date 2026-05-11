defmodule ForgeNexus.Cooldowns.UserCooldown do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "user_cooldowns" do
    field :action_key, :string
    field :expires_at, :utc_datetime

    belongs_to :user, ForgeNexus.Accounts.User

    timestamps()
  end

  def changeset(cooldown, attrs) do
    cooldown
    |> cast(attrs, [:user_id, :action_key, :expires_at])
    |> validate_required([:user_id, :action_key, :expires_at])
    |> unique_constraint([:user_id, :action_key])
  end
end
