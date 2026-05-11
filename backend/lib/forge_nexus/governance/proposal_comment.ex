defmodule ForgeNexus.Governance.ProposalComment do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "proposal_comments" do
    field :body, :string
    field :body_html, :string

    belongs_to :proposal, ForgeNexus.Governance.Proposal
    belongs_to :user, ForgeNexus.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(struct, attrs) do
    struct
    |> cast(attrs, [:body, :body_html, :proposal_id, :user_id])
    |> validate_required([:body, :proposal_id, :user_id])
  end
end
