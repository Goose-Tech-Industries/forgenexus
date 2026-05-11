defmodule ForgeNexus.Moderation.SuspiciousAccount do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "suspicious_accounts" do
    field :match_type, :string
    field :confidence, :float, default: 0.0
    field :reviewed, :boolean, default: false
    field :reviewed_at, :utc_datetime

    belongs_to :user, ForgeNexus.Accounts.User
    belongs_to :linked_user, ForgeNexus.Accounts.User
    belongs_to :reviewed_by, ForgeNexus.Accounts.User

    timestamps()
  end

  def changeset(suspicious_account, attrs) do
    suspicious_account
    |> cast(attrs, [:user_id, :linked_user_id, :match_type, :confidence])
    |> validate_required([:user_id, :linked_user_id, :match_type, :confidence])
    |> validate_inclusion(:match_type, ["ip_exact", "ip_range", "email_pattern", "fingerprint"])
    |> validate_number(:confidence, greater_than_or_equal_to: 0.0, less_than_or_equal_to: 1.0)
    |> unique_constraint([:user_id, :linked_user_id, :match_type])
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:linked_user_id)
  end

  def review_changeset(suspicious_account, attrs) do
    suspicious_account
    |> cast(attrs, [:reviewed, :reviewed_by_id, :reviewed_at])
    |> validate_required([:reviewed, :reviewed_by_id, :reviewed_at])
  end
end
