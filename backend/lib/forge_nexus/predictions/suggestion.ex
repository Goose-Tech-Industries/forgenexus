defmodule ForgeNexus.Predictions.Suggestion do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "suggestions" do
    field :title, :string
    field :description, :string
    field :status, :string, default: "pending"
    field :upvotes, :integer, default: 0
    field :downvotes, :integer, default: 0
    field :staff_response, :string

    belongs_to :user, ForgeNexus.Accounts.User

    timestamps()
  end

  def changeset(suggestion, attrs) do
    suggestion
    |> cast(attrs, [
      :title,
      :description,
      :status,
      :upvotes,
      :downvotes,
      :staff_response,
      :user_id
    ])
    |> validate_required([:title, :description, :user_id])
    |> validate_inclusion(:status, ~w(pending under_review accepted rejected completed))
  end
end
