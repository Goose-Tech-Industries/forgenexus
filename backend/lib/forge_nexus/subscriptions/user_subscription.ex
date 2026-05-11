defmodule ForgeNexus.Subscriptions.UserSubscription do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "user_subscriptions" do
    field :status, :string, default: "active"
    field :started_at, :utc_datetime
    field :expires_at, :utc_datetime
    field :cancelled_at, :utc_datetime
    field :paused_until, :utc_datetime
    field :payment_method, :string
    field :external_id, :string

    belongs_to :user, ForgeNexus.Accounts.User
    belongs_to :tier, ForgeNexus.Subscriptions.SubscriptionTier

    timestamps()
  end

  def changeset(subscription, attrs) do
    subscription
    |> cast(attrs, [:user_id, :tier_id, :status, :started_at, :expires_at, :cancelled_at, :paused_until, :payment_method, :external_id])
    |> validate_required([:user_id, :tier_id, :status])
    |> validate_inclusion(:status, ["active", "cancelled", "expired", "trial", "paused"])
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:tier_id)
  end
end
