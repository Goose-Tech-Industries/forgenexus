defmodule ForgeNexus.Governance.ProposalVote do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "proposal_votes" do
    field :vote, :string

    belongs_to :proposal, ForgeNexus.Governance.Proposal
    belongs_to :user, ForgeNexus.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(struct, attrs) do
    struct
    |> cast(attrs, [:vote, :proposal_id, :user_id])
    |> validate_required([:vote, :proposal_id, :user_id])
    |> validate_inclusion(:vote, ["yes", "no", "abstain"])
    |> unique_constraint([:proposal_id, :user_id])
  end
end
