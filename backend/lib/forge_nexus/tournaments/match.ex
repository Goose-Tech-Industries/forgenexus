defmodule ForgeNexus.Tournaments.Match do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "tournament_matches" do
    field :round, :integer
    field :position, :integer
    field :status, :string, default: "pending"
    field :scores, :map, default: %{}

    belongs_to :tournament, ForgeNexus.Tournaments.Tournament
    belongs_to :player1, ForgeNexus.Accounts.User
    belongs_to :player2, ForgeNexus.Accounts.User
    belongs_to :winner, ForgeNexus.Accounts.User

    timestamps()
  end

  def changeset(match, attrs) do
    match
    |> cast(attrs, [
      :tournament_id,
      :round,
      :position,
      :status,
      :scores,
      :player1_id,
      :player2_id,
      :winner_id
    ])
    |> validate_required([:tournament_id, :round, :position])
    |> validate_inclusion(:status, ~w(pending active completed bye))
  end
end
