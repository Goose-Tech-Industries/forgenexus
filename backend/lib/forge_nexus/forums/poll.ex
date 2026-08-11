defmodule ForgeNexus.Forums.Poll do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "polls" do
    field :question, :string
    field :is_multiple_choice, :boolean, default: false
    field :is_public, :boolean, default: true
    field :max_choices, :integer, default: 1
    field :closes_at, :utc_datetime
    field :voter_count, :integer, default: 0

    belongs_to :thread, ForgeNexus.Forums.Thread
    has_many :options, ForgeNexus.Forums.PollOption

    timestamps()
  end

  def changeset(poll, attrs) do
    poll
    |> cast(attrs, [
      :question,
      :is_multiple_choice,
      :is_public,
      :max_choices,
      :closes_at,
      :thread_id
    ])
    |> validate_required([:question, :thread_id])
    |> unique_constraint(:thread_id)
  end
end
