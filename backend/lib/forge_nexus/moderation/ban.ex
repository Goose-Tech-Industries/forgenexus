defmodule ForgeNexus.Moderation.Ban do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "bans" do
    field :type, :string, default: "temporary"
    field :reason, :string
    field :expires_at, :utc_datetime
    field :is_active, :boolean, default: true
    field :ip_address, :string

    belongs_to :user, ForgeNexus.Accounts.User
    belongs_to :banned_by, ForgeNexus.Accounts.User

    timestamps()
  end

  def changeset(ban, attrs) do
    ban
    |> cast(attrs, [:type, :reason, :expires_at, :ip_address, :user_id, :banned_by_id])
    |> validate_required([:reason, :banned_by_id])
    |> validate_inclusion(:type, ["temporary", "permanent", "ip"])
  end
end
