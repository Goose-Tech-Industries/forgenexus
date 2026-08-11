defmodule ForgeNexus.Forums.ReputationEvent do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "reputation_events" do
    field :event_type, :string
    field :points, :integer
    field :source_type, :string
    field :source_id, :binary_id

    belongs_to :user, ForgeNexus.Accounts.User

    timestamps(updated_at: false)
  end

  def changeset(event, attrs) do
    event
    |> cast(attrs, [:user_id, :event_type, :points, :source_type, :source_id])
    |> validate_required([:user_id, :event_type, :points])
    |> validate_inclusion(
      :event_type,
      ~w(post_liked achievement_earned thread_created best_answer user_given user_taken post_created manual)
    )
    |> foreign_key_constraint(:user_id)
  end
end
