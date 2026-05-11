defmodule ForgeNexus.Forums.WebhookDelivery do
  @moduledoc "Log of webhook delivery attempts (success and failure)."
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "webhook_deliveries" do
    field :event_type, :string
    field :payload, :map, default: %{}
    field :response_status, :integer
    field :response_body, :string
    field :latency_ms, :integer
    field :attempt, :integer, default: 1
    field :error, :string
    field :delivered_at, :utc_datetime

    belongs_to :webhook, ForgeNexus.Forums.ForumWebhook

    timestamps()
  end

  @required ~w(webhook_id event_type delivered_at attempt)a
  @optional ~w(payload response_status response_body latency_ms error)a

  def changeset(delivery, attrs) do
    delivery
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> foreign_key_constraint(:webhook_id)
  end
end
