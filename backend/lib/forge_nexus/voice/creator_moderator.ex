defmodule ForgeNexus.Voice.CreatorModerator do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @default_permissions %{
    "manage_chat" => true,
    "manage_redemptions" => false,
    "timeout_users" => true,
    "ban_users" => false,
    "manage_soundboard" => false,
    "manage_polls" => true,
    "manage_watch_party" => false,
    "start_recording" => false,
    "manage_roles" => false
  }

  schema "creator_moderators" do
    field :permissions, :map, default: @default_permissions

    belongs_to :community, ForgeNexus.Communities.Community
    belongs_to :creator, ForgeNexus.Accounts.User
    belongs_to :moderator, ForgeNexus.Accounts.User

    timestamps()
  end

  def changeset(mod, attrs) do
    mod
    |> cast(attrs, [:community_id, :creator_id, :moderator_id, :permissions])
    |> validate_required([:creator_id, :moderator_id])
    |> unique_constraint([:creator_id, :moderator_id])
  end

  def default_permissions, do: @default_permissions

  def has_permission?(%__MODULE__{permissions: perms}, permission) do
    Map.get(perms || @default_permissions, permission, false)
  end
end
