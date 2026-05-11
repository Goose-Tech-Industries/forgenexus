defmodule ForgeNexus.Governance.ElectionCandidate do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "election_candidates" do
    field :platform, :string
    field :is_accepted, :boolean, default: false
    field :vote_count, :integer, default: 0

    belongs_to :election, ForgeNexus.Governance.Election
    belongs_to :user, ForgeNexus.Accounts.User
    belongs_to :nominated_by, ForgeNexus.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(struct, attrs) do
    struct
    |> cast(attrs, [:platform, :is_accepted, :vote_count, :election_id, :user_id, :nominated_by_id])
    |> validate_required([:election_id, :user_id])
  end
end
