defmodule ForgeNexus.Predictions.PredictionOption do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "prediction_options" do
    field :label, :string
    field :total_amount, :integer, default: 0

    belongs_to :prediction, ForgeNexus.Predictions.Prediction

    timestamps()
  end

  def changeset(option, attrs) do
    option
    |> cast(attrs, [:label, :total_amount, :prediction_id])
    |> validate_required([:label, :prediction_id])
  end
end
