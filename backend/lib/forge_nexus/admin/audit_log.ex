defmodule ForgeNexus.Admin.AuditLog do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @categories ~w(settings forums plugins themes permissions)

  schema "admin_audit_logs" do
    field :action, :string
    field :category, :string
    field :target_type, :string
    field :target_id, :binary_id
    field :description, :string
    field :previous_state, :map, default: %{}
    field :new_state, :map, default: %{}
    field :is_rolled_back, :boolean, default: false
    field :rolled_back_at, :utc_datetime

    belongs_to :admin, ForgeNexus.Accounts.User
    belongs_to :rolled_back_by, ForgeNexus.Accounts.User

    timestamps()
  end

  def changeset(log, attrs) do
    log
    |> cast(attrs, [:action, :category, :target_type, :target_id, :description, :previous_state, :new_state, :admin_id])
    |> validate_required([:action, :category, :admin_id])
    |> validate_inclusion(:category, @categories)
    |> foreign_key_constraint(:admin_id)
  end

  def rollback_changeset(log, attrs) do
    log
    |> cast(attrs, [:is_rolled_back, :rolled_back_at, :rolled_back_by_id])
  end
end
