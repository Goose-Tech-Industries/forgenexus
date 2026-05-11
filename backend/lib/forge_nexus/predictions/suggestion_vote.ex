defmodule ForgeNexus.Predictions.SuggestionVote do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "suggestion_votes" do
    field :direction, :string

    belongs_to :suggestion, ForgeNexus.Predictions.Suggestion
    belongs_to :user, ForgeNexus.Accounts.User

    timestamps()
  end

  def changeset(vote, attrs) do
    vote
    |> cast(attrs, [:direction, :suggestion_id, :user_id])
    |> validate_required([:direction, :suggestion_id, :user_id])
    |> validate_inclusion(:direction, ~w(up down))
    |> unique_constraint([:suggestion_id, :user_id])
  end
end
