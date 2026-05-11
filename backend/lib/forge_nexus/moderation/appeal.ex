defmodule ForgeNexus.Moderation.Appeal do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "appeals" do
    field :type, :string
    field :target_id, :binary_id
    field :reason, :string
    field :status, :string, default: "pending"
    field :decision_note, :string
    field :decided_at, :utc_datetime

    belongs_to :user, ForgeNexus.Accounts.User
    belongs_to :reviewer, ForgeNexus.Accounts.User

    timestamps()
  end

  def changeset(appeal, attrs) do
    appeal
    |> cast(attrs, [:type, :target_id, :reason, :user_id])
    |> validate_required([:type, :target_id, :reason, :user_id])
    |> validate_inclusion(:type, ["ban", "warning"])
    |> foreign_key_constraint(:user_id)
  end

  def review_changeset(appeal, attrs) do
    appeal
    |> cast(attrs, [:status, :decision_note, :reviewer_id, :decided_at])
    |> validate_required([:status, :reviewer_id, :decided_at])
    |> validate_inclusion(:status, ["under_review", "approved", "denied"])
    |> foreign_key_constraint(:reviewer_id)
  end
end
