defmodule ForgeNexus.Predictions.PredictionBet do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "prediction_bets" do
    field :amount, :integer

    belongs_to :user, ForgeNexus.Accounts.User
    belongs_to :prediction, ForgeNexus.Predictions.Prediction
    belongs_to :option, ForgeNexus.Predictions.PredictionOption

    timestamps()
  end

  def changeset(bet, attrs) do
    bet
    |> cast(attrs, [:amount, :user_id, :prediction_id, :option_id])
    |> validate_required([:amount, :user_id, :prediction_id, :option_id])
    |> validate_number(:amount, greater_than: 0)
  end
end
