defmodule ForgeNexus.ThreadTypes.DebatePosition do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "debate_positions" do
    field :side, :string

    belongs_to :thread, ForgeNexus.Forums.Thread
    belongs_to :post, ForgeNexus.Forums.Post
    belongs_to :user, ForgeNexus.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(struct, attrs) do
    struct
    |> cast(attrs, [:side, :thread_id, :post_id, :user_id])
    |> validate_required([:side, :thread_id, :user_id])
    |> validate_inclusion(:side, ["pro", "con", "neutral"])
  end
end
