defmodule ForgeNexus.Billing.CommunitySubscription do
  @moduledoc """
  Community-level Stripe subscription. One row per Stripe subscription object.
  Drives the Community's `plan` + `plan_status` fields via the webhook handler.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  # Plans match the v3 revenue ladder. `free` is the default for unsubbed
  # communities; nothing is ever stored as `free` here — only paid tiers.
  @plans ~w(forum community creator platform enterprise houses)
  @statuses ~w(active trialing past_due canceled unpaid incomplete incomplete_expired)

  schema "community_subscriptions" do
    field :stripe_subscription_id, :string
    field :stripe_customer_id, :string
    field :stripe_price_id, :string
    field :plan, :string
    field :status, :string
    field :current_period_start, :utc_datetime
    field :current_period_end, :utc_datetime
    field :cancel_at_period_end, :boolean, default: false
    field :canceled_at, :utc_datetime
    field :metadata, :map, default: %{}

    belongs_to :community, ForgeNexus.Communities.Community

    timestamps()
  end

  def plans, do: @plans
  def statuses, do: @statuses

  def changeset(sub, attrs) do
    sub
    |> cast(attrs, [
      :community_id,
      :stripe_subscription_id,
      :stripe_customer_id,
      :stripe_price_id,
      :plan,
      :status,
      :current_period_start,
      :current_period_end,
      :cancel_at_period_end,
      :canceled_at,
      :metadata
    ])
    |> validate_required([:community_id, :stripe_subscription_id, :plan, :status])
    |> validate_inclusion(:plan, @plans)
    |> validate_inclusion(:status, @statuses)
    |> unique_constraint(:stripe_subscription_id)
  end
end
