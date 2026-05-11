defmodule ForgeNexus.Moderation.Report do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "reports" do
    field :reason, :string
    field :description, :string
    field :status, :string, default: "open"
    field :resolved_at, :utc_datetime
    field :reportable_type, :string
    field :reportable_id, :binary_id
    field :resolution_note, :string
    field :priority, :integer, default: 0

    belongs_to :reporter, ForgeNexus.Accounts.User
    belongs_to :resolver, ForgeNexus.Accounts.User
    belongs_to :assigned_to, ForgeNexus.Accounts.User

    timestamps()
  end

  def changeset(report, attrs) do
    report
    |> cast(attrs, [:reason, :description, :reportable_type, :reportable_id, :reporter_id])
    |> validate_required([:reason, :reportable_type, :reportable_id, :reporter_id])
    |> validate_inclusion(:reason, ["spam", "harassment", "inappropriate", "off_topic", "other"])
  end

  def resolve_changeset(report, attrs) do
    report
    |> cast(attrs, [:resolution_note, :resolver_id])
    |> validate_required([:resolver_id])
    |> put_change(:status, "resolved")
    |> put_change(:resolved_at, DateTime.utc_now() |> DateTime.truncate(:second))
  end

  def assign_changeset(report, attrs) do
    report
    |> cast(attrs, [:assigned_to_id])
    |> foreign_key_constraint(:assigned_to_id)
  end

  def dismiss_changeset(report, attrs) do
    report
    |> cast(attrs, [:resolution_note, :resolver_id])
    |> validate_required([:resolver_id])
    |> put_change(:status, "dismissed")
    |> put_change(:resolved_at, DateTime.utc_now() |> DateTime.truncate(:second))
  end
end
