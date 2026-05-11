defmodule ForgeNexus.Moderation.QuarantineRecord do
  @moduledoc """
  An audit trail for user quarantines. Records the user's original group
  memberships so unquarantine can restore them.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "quarantine_records" do
    field :original_group_ids, {:array, :binary_id}, default: []
    field :reason, :string
    field :quarantined_at, :utc_datetime_usec
    field :released_at, :utc_datetime_usec

    belongs_to :user, ForgeNexus.Accounts.User
    belongs_to :quarantined_by, ForgeNexus.Accounts.User

    timestamps()
  end

  def changeset(record, attrs) do
    record
    |> cast(attrs, [
      :user_id,
      :quarantined_by_id,
      :original_group_ids,
      :reason,
      :quarantined_at,
      :released_at
    ])
    |> validate_required([:user_id, :quarantined_at])
  end
end
