defmodule ForgeNexus.Predictions.Prediction do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "predictions" do
    field :title, :string
    field :description, :string
    field :status, :string, default: "open"
    field :closes_at, :utc_datetime
    field :resolved_at, :utc_datetime
    field :winning_option, :string

    belongs_to :created_by, ForgeNexus.Accounts.User
    has_many :options, ForgeNexus.Predictions.PredictionOption
    has_many :bets, ForgeNexus.Predictions.PredictionBet

    timestamps()
  end

  def changeset(prediction, attrs) do
    prediction
    |> cast(attrs, [:title, :description, :status, :closes_at, :resolved_at, :winning_option, :created_by_id])
    |> validate_required([:title, :created_by_id])
    |> validate_inclusion(:status, ~w(open locked resolved cancelled))
  end
end
