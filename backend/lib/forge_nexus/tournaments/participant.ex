defmodule ForgeNexus.Tournaments.Participant do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "tournament_participants" do
    field :seed, :integer
    field :wins, :integer, default: 0
    field :losses, :integer, default: 0
    field :points, :integer, default: 0
    field :is_eliminated, :boolean, default: false
    field :checked_in, :boolean, default: false
    field :checked_in_at, :utc_datetime
    field :prize_points, :integer

    belongs_to :tournament, ForgeNexus.Tournaments.Tournament
    belongs_to :user, ForgeNexus.Accounts.User

    timestamps()
  end

  def changeset(participant, attrs) do
    participant
    |> cast(attrs, [
      :tournament_id,
      :user_id,
      :seed,
      :wins,
      :losses,
      :points,
      :is_eliminated,
      :checked_in,
      :checked_in_at,
      :prize_points
    ])
    |> validate_required([:tournament_id, :user_id])
    |> unique_constraint([:tournament_id, :user_id])
  end
end
