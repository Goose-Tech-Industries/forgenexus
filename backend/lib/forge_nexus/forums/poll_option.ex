defmodule ForgeNexus.Forums.PollOption do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "poll_options" do
    field :text, :string
    field :vote_count, :integer, default: 0
    field :position, :integer, default: 0

    belongs_to :poll, ForgeNexus.Forums.Poll

    timestamps()
  end

  def changeset(option, attrs) do
    option
    |> cast(attrs, [:text, :position, :poll_id])
    |> validate_required([:text, :poll_id])
  end
end
