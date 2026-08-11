defmodule ForgeNexus.Platform.InfraCost do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}

  schema "infra_costs" do
    field :provider, :string
    field :service, :string
    field :amount_cents, :integer
    field :currency, :string, default: "usd"
    field :period_start, :date
    field :period_end, :date
    field :is_recurring, :boolean, default: true
    field :notes, :string

    timestamps()
  end

  def changeset(cost, attrs) do
    cost
    |> cast(attrs, [
      :provider,
      :service,
      :amount_cents,
      :currency,
      :period_start,
      :period_end,
      :is_recurring,
      :notes
    ])
    |> validate_required([:provider, :service, :amount_cents, :period_start, :period_end])
  end
end
