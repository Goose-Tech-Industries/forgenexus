defmodule ForgeNexus.Moderation.Warning do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "warnings" do
    field :type, :string, default: "warning"
    field :reason, :string
    field :points, :integer, default: 1
    field :expires_at, :utc_datetime
    field :is_active, :boolean, default: true

    belongs_to :user, ForgeNexus.Accounts.User
    belongs_to :issued_by, ForgeNexus.Accounts.User

    timestamps()
  end

  def changeset(warning, attrs) do
    warning
    |> cast(attrs, [:type, :reason, :points, :expires_at, :user_id, :issued_by_id])
    |> validate_required([:reason, :user_id, :issued_by_id])
    |> validate_inclusion(:type, ["warning", "cooldown", "read_only", "temp_ban"])
  end
end
