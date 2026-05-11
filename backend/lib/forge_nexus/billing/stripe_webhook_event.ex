defmodule ForgeNexus.Billing.StripeWebhookEvent do
  @moduledoc """
  Idempotency + audit log for Stripe webhook events. We persist the event_id
  with `Repo.insert/2` and treat the unique-constraint violation as the
  "already processed, skip" signal.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}

  schema "stripe_webhook_events" do
    field :stripe_event_id, :string
    field :type, :string
    field :payload, :map
    field :processed_at, :utc_datetime

    timestamps()
  end

  def changeset(evt, attrs) do
    evt
    |> cast(attrs, [:stripe_event_id, :type, :payload, :processed_at])
    |> validate_required([:stripe_event_id, :type, :payload])
    |> unique_constraint(:stripe_event_id)
  end
end
