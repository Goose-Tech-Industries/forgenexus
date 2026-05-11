defmodule ForgeNexus.ThreadTypes.AnswerVote do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "answer_votes" do
    field :value, :integer

    belongs_to :thread_answer, ForgeNexus.ThreadTypes.ThreadAnswer
    belongs_to :user, ForgeNexus.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(struct, attrs) do
    struct
    |> cast(attrs, [:value, :thread_answer_id, :user_id])
    |> validate_required([:value, :thread_answer_id, :user_id])
    |> validate_inclusion(:value, [1, -1])
  end
end
