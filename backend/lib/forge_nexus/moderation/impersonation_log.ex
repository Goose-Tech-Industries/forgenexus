defmodule ForgeNexus.Moderation.ImpersonationLog do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "impersonation_logs" do
    field :reason, :string
    field :started_at, :utc_datetime
    field :ended_at, :utc_datetime

    belongs_to :admin, ForgeNexus.Accounts.User
    belongs_to :target_user, ForgeNexus.Accounts.User

    timestamps()
  end

  def changeset(log, attrs) do
    log
    |> cast(attrs, [:admin_id, :target_user_id, :reason, :started_at])
    |> validate_required([:admin_id, :target_user_id, :reason, :started_at])
    |> foreign_key_constraint(:admin_id)
    |> foreign_key_constraint(:target_user_id)
  end

  def end_changeset(log, attrs) do
    log
    |> cast(attrs, [:ended_at])
    |> validate_required([:ended_at])
  end
end
