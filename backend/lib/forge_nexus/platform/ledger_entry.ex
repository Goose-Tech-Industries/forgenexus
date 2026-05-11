defmodule ForgeNexus.Platform.LedgerEntry do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "platform_ledger_entries" do
    field :type, :string
    field :source, :string
    field :amount_cents, :integer
    field :infra_allocation_cents, :integer
    field :profit_allocation_cents, :integer
    field :reference_type, :string
    field :reference_id, :binary_id
    field :description, :string
    field :metadata, :map, default: %{}

    belongs_to :community, ForgeNexus.Communities.Community

    timestamps()
  end

  def changeset(entry, attrs) do
    entry
    |> cast(attrs, [:community_id, :type, :source, :amount_cents, :infra_allocation_cents,
                     :profit_allocation_cents, :reference_type, :reference_id, :description, :metadata])
    |> validate_required([:type, :amount_cents, :infra_allocation_cents, :profit_allocation_cents])
  end
end
