defmodule ForgeNexus.Forums.PollVote do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "poll_votes" do
    belongs_to :poll, ForgeNexus.Forums.Poll
    belongs_to :option, ForgeNexus.Forums.PollOption
    belongs_to :user, ForgeNexus.Accounts.User

    timestamps()
  end

  def changeset(vote, attrs) do
    vote
    |> cast(attrs, [:poll_id, :option_id, :user_id])
    |> validate_required([:poll_id, :option_id, :user_id])
    |> unique_constraint([:option_id, :user_id])
    |> foreign_key_constraint(:poll_id)
    |> foreign_key_constraint(:option_id)
    |> foreign_key_constraint(:user_id)
  end
end
