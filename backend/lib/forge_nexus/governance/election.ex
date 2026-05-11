defmodule ForgeNexus.Governance.Election do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "elections" do
    field :position, :string
    field :max_winners, :integer, default: 1
    field :nomination_ends_at, :utc_datetime
    field :status, :string, default: "nominations"

    belongs_to :proposal, ForgeNexus.Governance.Proposal
    has_many :candidates, ForgeNexus.Governance.ElectionCandidate

    timestamps(type: :utc_datetime)
  end

  def changeset(struct, attrs) do
    struct
    |> cast(attrs, [:position, :max_winners, :nomination_ends_at, :status, :proposal_id])
    |> validate_required([:position, :proposal_id])
  end
end
